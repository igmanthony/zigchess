const color = @import("color.zig");
const Color = color.Color;

pub const PieceType = packed enum(u3) {
    pawn,
    knight,
    bishop,
    rook,
    queen,
    king,
    empty, // useful for move generation and doesn't take more space as enum is u3
    other, // useful for move generation and doesn't take more space as the enum is a u3;

    pub fn fromChar(char: u8) ?PieceType {
        return switch (char) {
            'P', 'p' => PieceType.pawn,
            'N', 'n' => PieceType.knight,
            'B', 'b' => PieceType.bishop,
            'R', 'r' => PieceType.rook,
            'Q', 'q' => PieceType.queen,
            'K', 'k' => PieceType.king,
            else => null,
        };
    }

    pub fn toChar(self: PieceType) u8 {
        return switch (self) {
            .pawn => ' ', // these are mostly for debugging at this point - caps is semi incorrect
            .knight => 'N',
            .bishop => 'B',
            .rook => 'R',
            .queen => 'Q',
            .king => 'K',
            .empty => '%', // these shouldn't have an ascii representation here for debugging
            .other => '#', // ditto
        };
    }
};

pub const Piece = packed struct {
    color: color.Color,
    piece_type: PieceType,

    pub fn toChar(self: Piece) u8 {
        const offset: u8 = if (self.color == Color.black) 32 else 0;
        return switch (self.piece_type) {
            .pawn => 'P' + offset,
            .knight => 'N' + offset,
            .bishop => 'B' + offset,
            .rook => 'R' + offset,
            .queen => 'Q' + offset,
            .king => 'K' + offset,
            .empty => '%', // these shouldn't have an ascii representation here for debugging
            .other => '#', // ditto
        };
    }

    pub fn fromChar(char: u8) ?Piece {
        return switch (char) {
            'a'...'z' => Piece{ .color = Color.black, .piece_type = PieceType.fromChar(char) orelse return null },
            'A'...'Z' => Piece{ .color = Color.white, .piece_type = PieceType.fromChar(char) orelse return null },
            else => null,
        };
    }
};
