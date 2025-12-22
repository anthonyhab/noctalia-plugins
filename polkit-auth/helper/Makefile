CC ?= cc
PKG_CONFIG ?= pkg-config
CFLAGS ?= -O2 -Wall -Wextra -DPOLKIT_AGENT_I_KNOW_API_IS_SUBJECT_TO_CHANGE
CFLAGS += $(shell $(PKG_CONFIG) --cflags polkit-agent-1)
LDFLAGS += $(shell $(PKG_CONFIG) --libs polkit-agent-1)

TARGET = noctalia-polkit-agent
SRC = noctalia-polkit-agent.c

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

install: $(TARGET)
	install -Dm755 $(TARGET) $(DESTDIR)/usr/local/bin/$(TARGET)

clean:
	rm -f $(TARGET)
