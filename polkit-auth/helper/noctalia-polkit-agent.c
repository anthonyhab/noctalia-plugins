#include <gio/gio.h>
#include <glib.h>
#include <glib/gstdio.h>
#include <polkit/polkit.h>
#include <polkitagent/polkitagent.h>
#include <pwd.h>
#include <string.h>
#include <unistd.h>

#define AGENT_OBJECT_PATH "/org/noctalia/PolkitAgent"
#define AGENT_INTERFACE "org.freedesktop.PolicyKit1.AuthenticationAgent"
#define AUTHORITY_SERVICE "org.freedesktop.PolicyKit1"
#define AUTHORITY_PATH "/org/freedesktop/PolicyKit1/Authority"
#define AUTHORITY_INTERFACE "org.freedesktop.PolicyKit1.Authority"

typedef struct {
  gchar *cookie;
  gchar *action_id;
  gchar *message;
  gchar *icon_name;
  gchar *user;
  gchar *prompt;
  gchar *last_error;
  gboolean echo_on;
  gboolean delivered;
  gboolean cancelled;
  gboolean completed;
  GHashTable *details;
  PolkitAgentSession *session;
  GDBusMethodInvocation *invocation;
} PendingRequest;

typedef struct {
  gchar *type;
  gchar *cookie;
  gchar *error;
  gchar *result;
} AgentEvent;

static GHashTable *pending_requests = NULL;
static GQueue *pending_queue = NULL;
static GQueue *event_queue = NULL;
static gchar *socket_path = NULL;
static GDBusConnection *system_bus = NULL;
static guint dbus_object_id = 0;

static void pending_request_free(PendingRequest *req) {
  if (!req)
    return;
  g_free(req->cookie);
  g_free(req->action_id);
  g_free(req->message);
  g_free(req->icon_name);
  g_free(req->user);
  g_free(req->prompt);
  g_free(req->last_error);
  if (req->details)
    g_hash_table_destroy(req->details);
  if (req->session)
    g_object_unref(req->session);
  if (req->invocation)
    g_object_unref(req->invocation);
  g_free(req);
}

static void agent_event_free(AgentEvent *event) {
  if (!event)
    return;
  g_free(event->type);
  g_free(event->cookie);
  g_free(event->error);
  g_free(event->result);
  g_free(event);
}

static void queue_remove_cookie(const gchar *cookie) {
  if (!cookie || !pending_queue)
    return;

  for (GList *iter = pending_queue->head; iter; ) {
    GList *next = iter->next;
    const gchar *item = iter->data;
    if (g_strcmp0(item, cookie) == 0) {
      g_free(iter->data);
      g_queue_delete_link(pending_queue, iter);
    }
    iter = next;
  }
}

static PendingRequest *find_request(const gchar *cookie) {
  if (!cookie || !pending_requests)
    return NULL;
  return g_hash_table_lookup(pending_requests, cookie);
}

static void enqueue_event(const gchar *type, const gchar *cookie, const gchar *error, const gchar *result) {
  if (!type || !cookie)
    return;
  if (!event_queue)
    event_queue = g_queue_new();
  AgentEvent *event = g_new0(AgentEvent, 1);
  event->type = g_strdup(type);
  event->cookie = g_strdup(cookie);
  if (error)
    event->error = g_strdup(error);
  if (result)
    event->result = g_strdup(result);
  g_queue_push_tail(event_queue, event);
}

static gchar *json_escape(const gchar *value) {
  if (!value)
    return g_strdup("");

  GString *out = g_string_new(NULL);
  for (const gchar *p = value; *p; p++) {
    switch (*p) {
      case '\\': g_string_append(out, "\\\\"); break;
      case '"': g_string_append(out, "\\\""); break;
      case '\n': g_string_append(out, "\\n"); break;
      case '\r': g_string_append(out, "\\r"); break;
      case '\t': g_string_append(out, "\\t"); break;
      default:
        if ((guchar)*p < 0x20) {
          g_string_append_printf(out, "\\u%04x", (guchar)*p);
        } else {
          g_string_append_c(out, *p);
        }
        break;
    }
  }

  return g_string_free(out, FALSE);
}

static gchar *request_to_json(PendingRequest *req, const gchar *type) {
  if (!req)
    return NULL;

  const gchar *event_type = type ? type : "request";
  gchar *action = json_escape(req->action_id ? req->action_id : "");
  gchar *message = json_escape(req->message ? req->message : "");
  gchar *icon = json_escape(req->icon_name ? req->icon_name : "");
  gchar *user = json_escape(req->user ? req->user : "");
  gchar *prompt = json_escape(req->prompt ? req->prompt : "");
  gchar *error = json_escape(req->last_error ? req->last_error : "");

  GString *out = g_string_new("{");
  g_string_append_printf(out, "\"type\":\"%s\"", event_type);
  g_string_append_printf(out, ",\"id\":\"%s\"", req->cookie);
  g_string_append_printf(out, ",\"actionId\":\"%s\"", action);
  g_string_append_printf(out, ",\"message\":\"%s\"", message);
  g_string_append_printf(out, ",\"icon\":\"%s\"", icon);
  g_string_append_printf(out, ",\"user\":\"%s\"", user);
  g_string_append_printf(out, ",\"prompt\":\"%s\"", prompt);
  g_string_append_printf(out, ",\"echo\":%s", req->echo_on ? "true" : "false");
  if (req->last_error)
    g_string_append_printf(out, ",\"error\":\"%s\"", error);

  g_string_append(out, ",\"details\":{");
  if (req->details) {
    GHashTableIter iter;
    gpointer key_ptr = NULL;
    gpointer value_ptr = NULL;
    gboolean first = TRUE;

    g_hash_table_iter_init(&iter, req->details);
    while (g_hash_table_iter_next(&iter, &key_ptr, &value_ptr)) {
      gchar *k = json_escape((const gchar *)key_ptr);
      gchar *v = json_escape((const gchar *)value_ptr);
      g_string_append_printf(out, "%s\"%s\":\"%s\"", first ? "" : ",", k, v);
      g_free(k);
      g_free(v);
      first = FALSE;
    }
  }
  g_string_append(out, "}");
  g_string_append(out, "}");

  g_free(action);
  g_free(message);
  g_free(icon);
  g_free(user);
  g_free(prompt);
  g_free(error);

  return g_string_free(out, FALSE);
}

static gchar *update_to_json(AgentEvent *event) {
  if (!event)
    return NULL;

  gchar *cookie = json_escape(event->cookie);
  gchar *error = json_escape(event->error ? event->error : "");
  gchar *result = json_escape(event->result ? event->result : "");

  GString *out = g_string_new("{");
  g_string_append_printf(out, "\"type\":\"%s\"", event->type ? event->type : "update");
  g_string_append_printf(out, ",\"id\":\"%s\"", cookie);
  if (event->error)
    g_string_append_printf(out, ",\"error\":\"%s\"", error);
  if (event->result)
    g_string_append_printf(out, ",\"result\":\"%s\"", result);
  g_string_append(out, "}");

  g_free(cookie);
  g_free(error);
  g_free(result);
  return g_string_free(out, FALSE);
}

static void session_request_cb(PolkitAgentSession *session, const gchar *request, gboolean echo_on, gpointer user_data) {
  PendingRequest *req = user_data;
  if (!req)
    return;

  g_free(req->prompt);
  req->prompt = g_strdup(request ? request : "");
  req->echo_on = echo_on;
}

static void session_show_error_cb(PolkitAgentSession *session, const gchar *text, gpointer user_data) {
  (void)session;
  PendingRequest *req = user_data;
  if (!req)
    return;
  g_free(req->last_error);
  req->last_error = g_strdup(text ? text : "");
  enqueue_event("update", req->cookie, req->last_error, NULL);
}

static void session_show_info_cb(PolkitAgentSession *session, const gchar *text, gpointer user_data) {
  (void)session;
  (void)text;
  (void)user_data;
}

static void session_completed_cb(PolkitAgentSession *session, gboolean gained, gpointer user_data) {
  PendingRequest *req = user_data;
  if (!req)
    return;

  if (req->invocation) {
    if (gained) {
      g_dbus_method_invocation_return_value(req->invocation, NULL);
    } else if (req->cancelled) {
      g_dbus_method_invocation_return_dbus_error(req->invocation,
        "org.freedesktop.PolicyKit1.Error.Cancelled",
        "Authentication cancelled");
    } else {
      g_dbus_method_invocation_return_dbus_error(req->invocation,
        "org.freedesktop.PolicyKit1.Error.Failed",
        "Authentication failed");
    }
  }

  req->completed = TRUE;
  if (gained) {
    enqueue_event("complete", req->cookie, NULL, "success");
    return;
  }

  if (req->cancelled) {
    enqueue_event("complete", req->cookie, NULL, "cancelled");
    return;
  }

  if (!req->last_error)
    req->last_error = g_strdup("Authentication failed");
  enqueue_event("update", req->cookie, req->last_error, NULL);
  enqueue_event("complete", req->cookie, NULL, "failed");
}

static gboolean parse_identity_uid(GVariant *identities, guint32 *uid_out) {
  if (!identities || !uid_out)
    return FALSE;

  GVariantIter iter;
  g_variant_iter_init(&iter, identities);

  const gchar *kind = NULL;
  GVariant *details = NULL;

  while (g_variant_iter_next(&iter, "(&s@a{sv})", &kind, &details)) {
    if (g_strcmp0(kind, "unix-user") == 0) {
      guint32 uid = 0;
      if (g_variant_lookup(details, "uid", "u", &uid)) {
        g_variant_unref(details);
        *uid_out = uid;
        return TRUE;
      }
    }
    g_variant_unref(details);
  }

  return FALSE;
}

static void begin_authentication(GVariant *params, GDBusMethodInvocation *invocation) {
  const gchar *action_id = NULL;
  const gchar *message = NULL;
  const gchar *icon_name = NULL;
  const gchar *cookie = NULL;
  GVariant *details = NULL;
  GVariant *identities = NULL;

  g_variant_get(params, "(&s&s&s@a{ss}&s@a(sa{sv}))",
                &action_id, &message, &icon_name, &details, &cookie, &identities);

  guint32 uid = (guint32)getuid();
  parse_identity_uid(identities, &uid);

  PolkitIdentity *identity = POLKIT_IDENTITY(polkit_unix_user_new((gint)uid));
  if (!identity) {
    g_variant_unref(details);
    g_variant_unref(identities);
    g_dbus_method_invocation_return_dbus_error(invocation,
      "org.freedesktop.PolicyKit1.Error.Failed",
      "Unable to create identity");
    return;
  }

  struct passwd *pwd = getpwuid(uid);
  const gchar *username = pwd ? pwd->pw_name : NULL;

  PendingRequest *req = g_new0(PendingRequest, 1);
  req->cookie = g_strdup(cookie);
  req->action_id = g_strdup(action_id);
  req->message = g_strdup(message);
  req->icon_name = g_strdup(icon_name);
  req->user = g_strdup(username ? username : "");
  req->details = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
  req->invocation = g_object_ref(invocation);

  if (details) {
    GVariantIter iter;
    const gchar *key = NULL;
    const gchar *value = NULL;
    g_variant_iter_init(&iter, details);
    while (g_variant_iter_next(&iter, "{&s&s}", &key, &value)) {
      g_hash_table_insert(req->details, g_strdup(key), g_strdup(value));
    }
  }

  req->session = polkit_agent_session_new(identity, cookie);
  g_object_unref(identity);

  if (!req->session) {
    g_variant_unref(details);
    g_variant_unref(identities);
    g_dbus_method_invocation_return_dbus_error(invocation,
      "org.freedesktop.PolicyKit1.Error.Failed",
      "Unable to start authentication session");
    pending_request_free(req);
    return;
  }

  g_signal_connect(req->session, "request", G_CALLBACK(session_request_cb), req);
  g_signal_connect(req->session, "show-error", G_CALLBACK(session_show_error_cb), req);
  g_signal_connect(req->session, "show-info", G_CALLBACK(session_show_info_cb), req);
  g_signal_connect(req->session, "completed", G_CALLBACK(session_completed_cb), req);

  if (!pending_requests)
    pending_requests = g_hash_table_new_full(g_str_hash, g_str_equal, NULL, (GDestroyNotify)pending_request_free);
  if (!pending_queue)
    pending_queue = g_queue_new();
  if (!event_queue)
    event_queue = g_queue_new();

  g_hash_table_insert(pending_requests, req->cookie, req);
  g_queue_push_tail(pending_queue, g_strdup(req->cookie));
  enqueue_event("request", req->cookie, NULL, NULL);

  polkit_agent_session_initiate(req->session);

  g_variant_unref(details);
  g_variant_unref(identities);
}

static void cancel_authentication(GVariant *params, GDBusMethodInvocation *invocation) {
  const gchar *cookie = NULL;
  g_variant_get(params, "(&s)", &cookie);

  PendingRequest *req = find_request(cookie);
  if (req && req->session) {
    req->cancelled = TRUE;
    polkit_agent_session_cancel(req->session);
  }

  g_dbus_method_invocation_return_value(invocation, NULL);
}

static void on_method_call(GDBusConnection *connection,
                           const gchar *sender,
                           const gchar *object_path,
                           const gchar *interface_name,
                           const gchar *method_name,
                           GVariant *params,
                           GDBusMethodInvocation *invocation,
                           gpointer user_data) {
  (void)connection;
  (void)sender;
  (void)object_path;
  (void)interface_name;
  (void)user_data;

  if (g_strcmp0(method_name, "BeginAuthentication") == 0) {
    begin_authentication(params, invocation);
    return;
  }

  if (g_strcmp0(method_name, "CancelAuthentication") == 0) {
    cancel_authentication(params, invocation);
    return;
  }

  g_dbus_method_invocation_return_dbus_error(invocation,
    "org.freedesktop.PolicyKit1.Error.Failed",
    "Unknown method");
}

static const gchar *agent_introspection_xml =
  "<node>"
  "  <interface name='org.freedesktop.PolicyKit1.AuthenticationAgent'>"
  "    <method name='BeginAuthentication'>"
  "      <arg type='s' name='action_id' direction='in'/>"
  "      <arg type='s' name='message' direction='in'/>"
  "      <arg type='s' name='icon_name' direction='in'/>"
  "      <arg type='a{ss}' name='details' direction='in'/>"
  "      <arg type='s' name='cookie' direction='in'/>"
  "      <arg type='a(sa{sv})' name='identities' direction='in'/>"
  "    </method>"
  "    <method name='CancelAuthentication'>"
  "      <arg type='s' name='cookie' direction='in'/>"
  "    </method>"
  "  </interface>"
  "</node>";

static gboolean register_agent(void) {
  GError *error = NULL;
  system_bus = g_bus_get_sync(G_BUS_TYPE_SYSTEM, NULL, &error);
  if (!system_bus) {
    g_printerr("Failed to connect to system bus: %s\n", error->message);
    g_clear_error(&error);
    return FALSE;
  }

  GDBusNodeInfo *node_info = g_dbus_node_info_new_for_xml(agent_introspection_xml, &error);
  if (!node_info) {
    g_printerr("Failed to parse introspection XML: %s\n", error->message);
    g_clear_error(&error);
    return FALSE;
  }

  const GDBusInterfaceVTable vtable = {
    .method_call = on_method_call,
    .get_property = NULL,
    .set_property = NULL
  };

  dbus_object_id = g_dbus_connection_register_object(
    system_bus,
    AGENT_OBJECT_PATH,
    node_info->interfaces[0],
    &vtable,
    NULL,
    NULL,
    &error
  );

  g_dbus_node_info_unref(node_info);

  if (dbus_object_id == 0) {
    g_printerr("Failed to register agent object: %s\n", error->message);
    g_clear_error(&error);
    return FALSE;
  }

  const gchar *locale = getenv("LANG");
  if (!locale || !*locale)
    locale = "en_US";

  const gchar *session_id = getenv("XDG_SESSION_ID");
  GVariantBuilder subject_builder;
  g_variant_builder_init(&subject_builder, G_VARIANT_TYPE("a{sv}"));

  if (session_id && *session_id) {
    g_variant_builder_add(&subject_builder, "{sv}", "session-id", g_variant_new_string(session_id));
  } else {
    g_variant_builder_add(&subject_builder, "{sv}", "uid", g_variant_new_uint32((guint32)getuid()));
  }

  const gchar *subject_kind = (session_id && *session_id) ? "unix-session" : "unix-user";

  GVariant *params = g_variant_new("((sa{sv})ss)", subject_kind, &subject_builder, locale, AGENT_OBJECT_PATH);

  g_dbus_connection_call_sync(
    system_bus,
    AUTHORITY_SERVICE,
    AUTHORITY_PATH,
    AUTHORITY_INTERFACE,
    "RegisterAuthenticationAgent",
    params,
    NULL,
    G_DBUS_CALL_FLAGS_NONE,
    -1,
    NULL,
    &error
  );

  if (error) {
    g_printerr("Failed to register authentication agent: %s\n", error->message);
    g_clear_error(&error);
    return FALSE;
  }

  return TRUE;
}

static gboolean write_response(GOutputStream *output, const gchar *text) {
  if (!output || !text)
    return FALSE;

  gsize bytes_written = 0;
  GError *error = NULL;
  gboolean ok = g_output_stream_write_all(output, text, strlen(text), &bytes_written, NULL, &error);
  if (!ok) {
    if (error) {
      g_printerr("Failed to write response: %s\n", error->message);
      g_clear_error(&error);
    }
  }
  return ok;
}

static gchar *read_line(GDataInputStream *data_stream) {
  GError *error = NULL;
  gsize length = 0;
  gchar *line = g_data_input_stream_read_line(data_stream, &length, NULL, &error);
  if (error) {
    g_printerr("Failed to read command: %s\n", error->message);
    g_clear_error(&error);
  }
  return line;
}

static gboolean handle_command(const gchar *line, GDataInputStream *data_stream, GOutputStream *output) {
  if (!line)
    return FALSE;

  if (g_strcmp0(line, "PING") == 0) {
    write_response(output, "PONG\n");
    return TRUE;
  }

  if (g_strcmp0(line, "NEXT") == 0) {
    while (event_queue && !g_queue_is_empty(event_queue)) {
      AgentEvent *event = g_queue_pop_head(event_queue);
      if (!event)
        continue;
      PendingRequest *req = find_request(event->cookie);
      gchar *json = NULL;
      if (g_strcmp0(event->type, "request") == 0) {
        if (req) {
          req->delivered = TRUE;
          json = request_to_json(req, "request");
        }
      } else if (g_strcmp0(event->type, "update") == 0 || g_strcmp0(event->type, "complete") == 0) {
        json = update_to_json(event);
      }

      if (json) {
        write_response(output, json);
        write_response(output, "\n");
        g_free(json);
        if (req && req->completed && g_strcmp0(event->type, "complete") == 0) {
          queue_remove_cookie(req->cookie);
          if (pending_requests)
            g_hash_table_remove(pending_requests, req->cookie);
        }
        agent_event_free(event);
        return TRUE;
      }
      agent_event_free(event);
    }
    write_response(output, "\n");
    return TRUE;
  }

  if (g_str_has_prefix(line, "RESPOND ")) {
    const gchar *cookie = line + strlen("RESPOND ");
    gchar *password = read_line(data_stream);
    PendingRequest *req = find_request(cookie);
    if (!req || !req->session) {
      g_free(password);
      write_response(output, "ERROR\n");
      return TRUE;
    }

    polkit_agent_session_response(req->session, password ? password : "");
    g_free(password);
    write_response(output, "OK\n");
    return TRUE;
  }

  if (g_str_has_prefix(line, "CANCEL ")) {
    const gchar *cookie = line + strlen("CANCEL ");
    PendingRequest *req = find_request(cookie);
    if (req && req->session) {
      req->cancelled = TRUE;
      polkit_agent_session_cancel(req->session);
      write_response(output, "OK\n");
    } else {
      write_response(output, "ERROR\n");
    }
    return TRUE;
  }

  write_response(output, "ERROR\n");
  return TRUE;
}

static gboolean on_incoming(GSocketService *service, GSocketConnection *connection, GObject *source_object, gpointer user_data) {
  (void)service;
  (void)source_object;
  (void)user_data;

  GInputStream *input = g_io_stream_get_input_stream(G_IO_STREAM(connection));
  GOutputStream *output = g_io_stream_get_output_stream(G_IO_STREAM(connection));
  GDataInputStream *data_stream = g_data_input_stream_new(input);

  gchar *line = read_line(data_stream);
  if (line) {
    handle_command(line, data_stream, output);
  }

  g_free(line);
  g_object_unref(data_stream);
  g_io_stream_close(G_IO_STREAM(connection), NULL, NULL);
  return TRUE;
}

static gchar *default_socket_path(void) {
  const gchar *runtime_dir = g_get_user_runtime_dir();
  if (!runtime_dir)
    runtime_dir = g_get_tmp_dir();
  return g_build_filename(runtime_dir, "noctalia-polkit-agent.sock", NULL);
}

static int run_daemon(void) {
  if (!register_agent())
    return 1;

  GError *error = NULL;
  if (!socket_path)
    socket_path = default_socket_path();

  g_unlink(socket_path);

  GSocketService *service = g_socket_service_new();
  GSocketAddress *address = g_unix_socket_address_new(socket_path);
  gboolean added = g_socket_listener_add_address(
    G_SOCKET_LISTENER(service),
    address,
    G_SOCKET_TYPE_STREAM,
    G_SOCKET_PROTOCOL_DEFAULT,
    NULL,
    NULL,
    &error
  );

  g_object_unref(address);

  if (!added) {
    g_printerr("Failed to bind socket: %s\n", error->message);
    g_clear_error(&error);
    g_object_unref(service);
    return 1;
  }

  g_signal_connect(service, "incoming", G_CALLBACK(on_incoming), NULL);
  g_socket_service_start(service);

  GMainLoop *loop = g_main_loop_new(NULL, FALSE);
  g_main_loop_run(loop);

  g_main_loop_unref(loop);
  g_object_unref(service);
  return 0;
}

static gboolean client_send(const gchar *command, const gchar *payload, GString *response) {
  if (!socket_path)
    socket_path = default_socket_path();

  GError *error = NULL;
  GSocket *socket = g_socket_new(G_SOCKET_FAMILY_UNIX, G_SOCKET_TYPE_STREAM, G_SOCKET_PROTOCOL_DEFAULT, &error);
  if (!socket) {
    if (error)
      g_clear_error(&error);
    return FALSE;
  }

  GSocketAddress *address = g_unix_socket_address_new(socket_path);
  if (!g_socket_connect(socket, address, NULL, &error)) {
    if (error)
      g_clear_error(&error);
    g_object_unref(address);
    g_object_unref(socket);
    return FALSE;
  }
  g_object_unref(address);

  GSocketConnection *connection = g_socket_connection_factory_create_connection(socket);
  if (!connection) {
    g_object_unref(socket);
    return FALSE;
  }

  GInputStream *input = g_io_stream_get_input_stream(G_IO_STREAM(connection));
  GOutputStream *output = g_io_stream_get_output_stream(G_IO_STREAM(connection));

  GString *payload_str = g_string_new(command);
  g_string_append(payload_str, "\n");
  if (payload) {
    g_string_append(payload_str, payload);
    g_string_append(payload_str, "\n");
  }

  gsize bytes_written = 0;
  gboolean ok = g_output_stream_write_all(output, payload_str->str, payload_str->len, &bytes_written, NULL, &error);
  g_string_free(payload_str, TRUE);

  if (!ok) {
    if (error)
      g_clear_error(&error);
    g_object_unref(connection);
    return FALSE;
  }

  GDataInputStream *data_stream = g_data_input_stream_new(input);
  gchar *line = read_line(data_stream);
  if (response && line) {
    g_string_assign(response, line);
  }

  g_free(line);
  g_object_unref(data_stream);
  g_io_stream_close(G_IO_STREAM(connection), NULL, NULL);
  g_object_unref(connection);
  return TRUE;
}

static gchar *read_stdin_password(void) {
  GString *buffer = g_string_new(NULL);
  int ch;
  while ((ch = getchar()) != EOF) {
    if (ch == '\n')
      break;
    g_string_append_c(buffer, (gchar)ch);
  }
  return g_string_free(buffer, FALSE);
}

int main(int argc, char **argv) {
  gboolean opt_daemon = FALSE;
  gboolean opt_ping = FALSE;
  gboolean opt_next = FALSE;
  gchar *opt_respond = NULL;
  gchar *opt_cancel = NULL;
  gchar *opt_password = NULL;
  gboolean opt_password_stdin = FALSE;

  GOptionEntry entries[] = {
    {"daemon", 0, 0, G_OPTION_ARG_NONE, &opt_daemon, "Run the polkit agent daemon", NULL},
    {"ping", 0, 0, G_OPTION_ARG_NONE, &opt_ping, "Check if the daemon is reachable", NULL},
    {"next", 0, 0, G_OPTION_ARG_NONE, &opt_next, "Fetch the next pending request", NULL},
    {"respond", 0, 0, G_OPTION_ARG_STRING, &opt_respond, "Respond to a request (cookie)", "COOKIE"},
    {"cancel", 0, 0, G_OPTION_ARG_STRING, &opt_cancel, "Cancel a request (cookie)", "COOKIE"},
    {"password", 0, 0, G_OPTION_ARG_STRING, &opt_password, "Password for --respond", "PASSWORD"},
    {"password-stdin", 0, 0, G_OPTION_ARG_NONE, &opt_password_stdin, "Read password from stdin", NULL},
    {"socket", 0, 0, G_OPTION_ARG_STRING, &socket_path, "Override socket path", "PATH"},
    {NULL}
  };

  GOptionContext *context = g_option_context_new(NULL);
  g_option_context_add_main_entries(context, entries, NULL);

  GError *error = NULL;
  if (!g_option_context_parse(context, &argc, &argv, &error)) {
    g_printerr("Option parse error: %s\n", error->message);
    g_clear_error(&error);
    g_option_context_free(context);
    return 1;
  }
  g_option_context_free(context);

  if (opt_daemon)
    return run_daemon();

  if (opt_ping) {
    GString *response = g_string_new(NULL);
    gboolean ok = client_send("PING", NULL, response);
    gboolean success = ok && g_strcmp0(response->str, "PONG") == 0;
    g_string_free(response, TRUE);
    return success ? 0 : 1;
  }

  if (opt_next) {
    GString *response = g_string_new(NULL);
    gboolean ok = client_send("NEXT", NULL, response);
    if (ok && response->len > 0)
      g_print("%s\n", response->str);
    g_string_free(response, TRUE);
    return ok ? 0 : 1;
  }

  if (opt_respond) {
    if (!opt_password || opt_password_stdin) {
      g_free(opt_password);
      opt_password = read_stdin_password();
    }

    GString *response = g_string_new(NULL);
    GString *command = g_string_new(NULL);
    g_string_printf(command, "RESPOND %s", opt_respond);
    gboolean ok = client_send(command->str, opt_password, response);
    g_string_free(command, TRUE);
    gboolean success = ok && g_strcmp0(response->str, "OK") == 0;
    g_string_free(response, TRUE);
    return success ? 0 : 1;
  }

  if (opt_cancel) {
    GString *response = g_string_new(NULL);
    GString *command = g_string_new(NULL);
    g_string_printf(command, "CANCEL %s", opt_cancel);
    gboolean ok = client_send(command->str, NULL, response);
    g_string_free(command, TRUE);
    gboolean success = ok && g_strcmp0(response->str, "OK") == 0;
    g_string_free(response, TRUE);
    return success ? 0 : 1;
  }

  g_printerr("No action specified. Use --daemon, --ping, --next, --respond, or --cancel.\n");
  return 1;
}
