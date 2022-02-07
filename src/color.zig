/// Color indicates the color of pieces and player turns. It never indicates
/// the color of the chess squares, which are dark and light (same as dark
/// and light-squared bishops)
pub const Color = enum(u1) {
    white = 0,
    black = 1,

    /// left argument if white, right argument if black;
    pub inline fn wlbr(self: Color, comptime T: type, left: T, right: T) T {
        return switch (self) {
            .white => left,
            .black => right,
        };
    }

    pub inline fn invert(self: Color) Color {
        return switch (self) {
            .white => Color.black,
            .black => Color.white,
        };
    }
};

pub fn fromChar(char: u8) ?Color {
    return switch (char) {
        'w', 'W' => Color.white,
        'b', 'B' => Color.black,
        else => null,
    };
}
