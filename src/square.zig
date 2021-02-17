const bitboard = @import("bitboard.zig");
const errors = @import("errors.zig");
const Bitboard = bitboard.Bitboard;
const InvalidASCII = errors.ChessError.InvalidASCII;

pub const Square = packed struct {
    file: u3, // file a -> 0; h -> 7
    rank: u3, // rank 1st -> 0; 8th -> 7

    /// gives the number of the square (0 to 63)
    pub fn index(self: Square) callconv(.Inline) u6 {
        return @bitCast(u6, self);
    }

    /// sets a non-wrapping integer offset to the square
    pub fn offset(self: Square, off: i32) callconv(.Inline) ?Square {
        return fromInt(i32, @as(i32, self.index()) + off);
    }

    /// Measures the greatest distance between two squares (file or rank)
    pub fn distance(self: Square, other: Square) callconv(.Inline) u3 {
        const f = if (self.file > other.file) self.file - other.file else other.file - self.file;
        const r = if (self.rank > other.rank) self.rank - other.rank else other.rank - self.rank;
        return if (f > r) f else r;
    }

    /// Checks if a square is in a bitboard.
    pub fn in(self: Square, bit: Bitboard) callconv(.Inline) bool {
        return ((bit.bits >> self.index()) & 1) > 0;
    }

    /// Converts the square to a bitboard
    pub fn toBitboard(self: Square) callconv(.Inline) Bitboard {
        return Bitboard{.bits = @as(u64, 1) << self.index()};
        // return Bitboard{ .bits = (@as(u64, 1) << self.index()) };
    }

    pub fn toString(self: Square) [2]u8 {
        const f: u8 = @as(u8, self.file) + 'a';
        const r: u8 = @as(u8, self.rank) + '1';
        return [2]u8{ f, r };
    }
};

/// makes a square from a u6 via direct bitcast
pub fn fromIndex(number: u6) callconv(.Inline) Square {
    return @bitCast(Square, number);
}

/// makes a square from an integer
pub fn fromInt(comptime T: type, int: T) callconv(.Inline) ?Square {
    return switch (int) {
        0...63 => fromIndex(@intCast(u6, int)),
        else => null,
    };
}

/// makes a square from algebraic notation (e.g., e6, g2, 1...8 ranks and a...h files)
pub fn fromNotation(algebraic_notation: []const u8) !?Square {
    var rank: u3 = undefined;
    var file: u3 = undefined;
    for (algebraic_notation) |char| {
        switch (char) {
            'a'...'h' => file = @intCast(u3, (char - 'a')),
            '1'...'8' => rank = @intCast(u3, (char - '1')),
            '-' => return null,
            else => return InvalidASCII,
        }
    }
    return Square{ .file = file, .rank = rank };
}
