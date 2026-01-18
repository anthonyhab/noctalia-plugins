.pragma library

function getAppProfiles(Color) {
    return {
        "1password": { color: "#0094F5", accentColor: "#0094F5", label: "1Password", glyph: "lock" },
        "bitwarden": { color: "#175DDC", accentColor: "#175DDC", label: "Bitwarden", glyph: "lock" },
        "keepassxc": { color: "#6A9955", accentColor: "#6A9955", label: "KeePassXC", glyph: "lock" },
        "proton-pass": { color: "#6D4AFF", accentColor: "#6D4AFF", label: "Proton Pass", glyph: "lock" },
        "gpg": { color: Color.mPrimary, accentColor: Color.mPrimary, label: "GPG", glyph: "key" },
        "git": { color: "#F05032", accentColor: "#F05032", label: "Git", glyph: "brand-git" },
        "kitty": { color: "#F49D1A", accentColor: "#F49D1A", label: "Kitty Terminal", glyph: "terminal-2" }
    };
}

function getContextModel(request, requestor, subject, appProfiles, Color) {
    if (!request || !request.id) return { color: Color.mPrimary, accentColor: Color.mPrimary, label: "System", glyph: "shield" };

    const actionId = (request.actionId || "").toLowerCase();
    const appName = (requestor && requestor.displayName || "").toLowerCase();
    const exe = (subject && subject.exe || "").toLowerCase();
    const full = (actionId + " " + appName + " " + exe);

    if (full.includes("1password")) return appProfiles["1password"];
    if (full.includes("bitwarden")) return appProfiles["bitwarden"];
    if (full.includes("keepassxc")) return appProfiles["keepassxc"];
    if (full.includes("proton-pass") || full.includes("protonpass")) return appProfiles["proton-pass"];
    if (full.includes("gpg") || full.includes("openpgp")) return appProfiles["gpg"];
    if (full.includes("git")) return appProfiles["git"];
    if (full.includes("kitty")) return appProfiles["kitty"];

    return { color: Color.mPrimary, accentColor: Color.mPrimary, label: "System", glyph: "shield" };
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
    const isGpg = (request.hint && request.hint.kind === "gpg") || desc.includes("OpenPGP");
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
