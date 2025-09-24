pub const types = @import("types.zig");
pub const replacers = @import("replacers.zig");

// Re-export key types and functions
pub const ReplacerResult = types.ReplacerResult;
pub const EditOptions = types.EditOptions;
pub const MatchContext = types.MatchContext;

pub const simpleReplacer = replacers.simpleReplacer;
pub const lineTrimmedReplacer = replacers.lineTrimmedReplacer;
pub const whitespaceNormalizedReplacer = replacers.whitespaceNormalizedReplacer;
pub const indentationFlexibleReplacer = replacers.indentationFlexibleReplacer;
pub const escapeNormalizedReplacer = replacers.escapeNormalizedReplacer;
pub const blockAnchorReplacer = replacers.blockAnchorReplacer;
