/// Color indicates the color of pieces and player turns. It never indicates
/// the color of the chess squares, which are dark and light (same as dark
/// and light-squared bishops)
pub const Color = packed enum(u1) {
    white = 0,
    black = 1,

    /// left argument if white, right argument if black;
    pub fn wlbr(self: Color, comptime T: type, left: T, right: T) callconv(.Inline) T {
        return switch (self) {
            .white => left,
            .black => right,
        };
    }

    pub fn invert(self: Color) callconv(.Inline) Color {
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
