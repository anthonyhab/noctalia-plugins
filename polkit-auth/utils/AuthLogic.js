.pragma library

function getAppProfiles(Color) {
    return {
        "1password": { color: "#0094F5", accentColor: "#0094F5", label: "1Password", glyph: "lock", kind: "vault" },
        "bitwarden": { color: "#175DDC", accentColor: "#175DDC", label: "Bitwarden", glyph: "lock", kind: "vault" },
        "keepassxc": { color: "#6A9955", accentColor: "#6A9955", label: "KeePassXC", glyph: "lock", kind: "vault" },
        "proton-pass": { color: "#6D4AFF", accentColor: "#6D4AFF", label: "Proton Pass", glyph: "lock", kind: "vault" },
        "gpg": { color: Color.mPrimary, accentColor: Color.mPrimary, label: "GPG", glyph: "key", kind: "system" },
        "ssh": { color: Color.mPrimary, accentColor: Color.mPrimary, label: "SSH", glyph: "key", kind: "system" },
        "git": { color: "#F05032", accentColor: "#F05032", label: "Git", glyph: "brand-git", kind: "system" },
        "kitty": { color: "#F49D1A", accentColor: "#F49D1A", label: "Kitty Terminal", glyph: "terminal-2", kind: "system" }
    };
}

function getContextModel(request, requestor, subject, appProfiles, Color) {
    if (!request || !request.id) return { color: Color.mPrimary, accentColor: Color.mPrimary, label: "System", glyph: "shield", kind: "system" };

    const actionId = (request.actionId || "").toLowerCase();
    const appName = (requestor && requestor.name || "").toLowerCase();
    const exe = (subject && subject.exe || "").toLowerCase();
    const msg = (request.message || "").toLowerCase();
    const desc = (request.description || "").toLowerCase();
    const kind = (request.source || "").toLowerCase();
    const full = (actionId + " " + appName + " " + exe + " " + msg + " " + desc + " " + kind);

    if (full.includes("1password")) return appProfiles["1password"];
    if (full.includes("bitwarden")) return appProfiles["bitwarden"];
    if (full.includes("keepassxc")) return appProfiles["keepassxc"];
    if (full.includes("proton-pass") || full.includes("protonpass")) return appProfiles["proton-pass"];
    if (full.includes("gpg") || full.includes("openpgp")) return appProfiles["gpg"];
    if (full.includes("ssh") || full.includes("ssh-agent")) return appProfiles["ssh"];
    if (full.includes("git")) return appProfiles["git"];
    if (full.includes("kitty")) return appProfiles["kitty"];

    return { color: Color.mPrimary, accentColor: Color.mPrimary, label: "System", glyph: "shield", kind: "system" };
}

function getRichContext(request, Color, secondaryAccent) {
    if (!request || !request.id) return null;
    const msg = (request.message || "").toLowerCase();
    const desc = (request.description || "").toLowerCase();
    const full = msg + " " + desc;

    if (full.includes("gpg") || full.includes("openpgp"))
        return { icon: "key", action: "unlock GPG key", color: Color.mPrimary };
    if (full.includes("ssh") || full.includes("ssh-agent"))
        return { icon: "key", action: "unlock SSH key", color: secondaryAccent };
    if (full.includes("git"))
        return { icon: "brand-git", action: "authenticate Git", color: secondaryAccent };

    return null;
}

function getGpgInfo(request) {
    if (!request || !request.id || !request.description) return null;

    const desc = request.description;
    const source = (request.source || "").toLowerCase();
    const lowerDesc = desc.toLowerCase();
    const isGpg = source === "pinentry" || lowerDesc.includes("openpgp") || lowerDesc.includes("gpg");
    if (!isGpg) return null;

    const identityMatch = desc.match(/"([^"]+)"/);
    const keyIdMatch = desc.match(/ID ([A-F0-9]+)/);
    const keyTypeMatch = desc.match(/\n([^,\n]+), ID/);
    const createdMatch = desc.match(/created ([0-9-]{10})/);

    const identity = identityMatch ? identityMatch[1] : "";
    let cleanIdentity = identity.replace(" (github)", "");
    let name = cleanIdentity;
    let email = "";
    const emailMatch = cleanIdentity.match(/<([^>]+)>/);
    if (emailMatch) {
        name = cleanIdentity.replace(emailMatch[0], "").trim();
        email = emailMatch[1];
    }

    return {
        identity: identity,
        name: name,
        email: email,
        keyId: keyIdMatch ? keyIdMatch[1] : "",
        keyType: keyTypeMatch ? keyTypeMatch[1] : "",
        created: createdMatch ? createdMatch[1] : "",
        isGithub: identity.includes("(github)")
    };
}

function getDisplayAction(request, richContext, secondaryAccent) {
    if (!request || !request.id || !request.message) return "authenticate";
    if (richContext) return richContext.action;

    const msg = request.message;
    const runMatch = msg.match(/run `([^']+)'/);
    if (runMatch && runMatch[1]) {
        const parts = runMatch[1].split('/');
        const exe = parts[parts.length - 1];
        const highlightColor = richContext ? richContext.color : secondaryAccent;
        return "run <font color='" + highlightColor + "'><b>" + exe + "</b></font>";
    }

    if (msg.length < 40) return msg.toLowerCase();
    return "perform this action";
}

function getContextCardModel(contextModel, gpgInfo) {
    if (gpgInfo !== null) {
        return {
            variant: "gpg",
            accentColor: contextModel ? contextModel.accentColor : "#FFFFFF",
            tileIcon: gpgInfo.isGithub ? "brand-github" : "key",
            tileIconPointSize: 20,
            name: gpgInfo.name || "Unknown",
            email: gpgInfo.email || "",
            meta: (gpgInfo.keyType && gpgInfo.keyId) ? (gpgInfo.keyType + " • " + gpgInfo.keyId) : ""
        };
    }

    if (contextModel && contextModel.kind === "vault") {
        return {
            variant: "vault",
            accentColor: contextModel.accentColor,
            tileIcon: contextModel.glyph || "lock",
            tileIconPointSize: 18,
            label: contextModel.label || "Vault",
            richText: "Unlock <b><font color='" + contextModel.accentColor + "'>" + contextModel.label + "</font></b> vault"
        };
    }

    return null;
}
