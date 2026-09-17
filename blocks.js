.pragma library

// The marker-delimited blocks Duck owns inside files it shares with the user.
//
// Duck writes into two files it does not own: the Omarchy menu extension, which
// the shell reads from one fixed path with no drop-in beside it, and -- for
// removal only -- hyprland.lua, where older versions put a require line. Both
// edits are fenced so they can be taken out exactly, leaving whatever the user
// put around them untouched.
//
// The comment prefix differs per file (`//` for JSONC, `--` for Lua), so it is
// passed in rather than assumed.

function beginMarker(prefix) {
    return prefix + " >>> duck: begin (managed by the Duck plugin) >>>";
}

function endMarker(prefix) {
    return prefix + " <<< duck: end <<<";
}

function escapeRe(value) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// Matches on the stable head of each marker only. Blocks written by earlier
// versions named install.sh in the begin marker, and they have to be removable
// by a version that no longer writes that text.
function blockRe(prefix) {
    return new RegExp(
        "\\n*[ \\t]*" + escapeRe(prefix + " >>> duck: begin") + "[^\\n]*\\n"
        + "[\\s\\S]*?"
        + "[ \\t]*" + escapeRe(prefix + " <<< duck: end") + "[^\\n]*\\n?",
        "g");
}

function has(text, prefix) {
    return blockRe(prefix).test(text);
}

// Takes the blank line before the block with it, so repeated add/remove cycles
// do not accumulate whitespace.
function strip(text, prefix) {
    return text.replace(blockRe(prefix), "\n");
}

// Rewrites Duck's block in place: strip whatever is there, then insert fresh
// just inside the object's closing brace, leaving everything above untouched.
// Returns null when there is no brace to insert before, which means the file is
// not something Duck should be writing into.
function write(text, prefix, rows) {
    const cleaned = strip(text, prefix);
    const close = cleaned.lastIndexOf("}");
    if (close === -1) return null;

    const block = [beginMarker(prefix)].concat(rows).concat([endMarker(prefix)]).join("\n");
    return cleaned.slice(0, close).replace(/\n+$/, "") + "\n" + block + "\n" + cleaned.slice(close);
}
