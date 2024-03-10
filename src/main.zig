const std = @import("std");

const base32 = "0123456789bcdefghjkmnpqrstuvwxyz";
const bits: [5]u8 = .{ 16, 8, 4, 2, 1 };

pub fn main() !void {
    const lat: f32 = 47.59;
    const lon: f32 = -120.67;

    const geohash = encode(lat, lon, 12);
    std.debug.print("{s}\n", .{geohash});

    const decoded = decode(&geohash);
    std.debug.print("{any}", .{decoded});
}

fn decode(geohash: []const u8) ![4]f32 {
    var lat_range: [2]f32 = .{ -90, 90 };
    var lon_range: [2]f32 = .{ -180, 180 };

    var lat_err: f32 = 90;
    var lon_err: f32 = 180;

    var even: bool = true;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var decodeMap = std.AutoHashMap(u8, u8).init(arena.allocator());
    defer decodeMap.deinit();
    for (base32, 0..) |c, index| {
        try decodeMap.put(c, @intCast(index));
    }

    for (geohash) |c| {
        const cd = decodeMap.get(c) orelse return DecodeError.InvalidDecodedCharacter;
        for (bits) |mask| {
            if (even) {
                lon_err /= 2;
                if ((cd & mask) == 0) {
                    lon_range = .{ (lon_range[0] + lon_range[1]) / 2, lon_range[1] };
                } else {
                    lon_range = .{ lon_range[0], (lon_range[0] + lon_range[1]) / 2 };
                }
            } else {
                lat_err /= 2;
                if ((cd & mask) == 0) {
                    lat_range = .{ (lat_range[0] + lat_range[1]) / 2, lat_range[1] };
                } else {
                    lat_range = .{ lat_range[0], (lat_range[0] + lat_range[1]) / 2 };
                }
            }
            even = !even;
        }
    }
    const lat: f32 = (lat_range[0] + lat_range[1]) / 2;
    const lon: f32 = (lon_range[0] + lon_range[1]) / 2;
    return .{ lat, lon, lat_err, lon_err };
}

fn encode(lat: f32, lon: f32, comptime precision: u8) [precision]u8 {
    var lat_range: [2]f32 = .{ -90, 90 };
    var lon_range: [2]f32 = .{ -180, 180 };

    var geohash = [_]u8{0} ** precision;

    var bit: u4 = 0;
    var ch: u8 = 0;
    var even: bool = true;
    var i: u8 = 0;
    while (geohash[precision - 1] == 0) {
        if (even) {
            const mid: f32 = (lon_range[0] + lon_range[1]) / 2;
            if (lon > mid) {
                ch = ch | bits[bit];
                lon_range = .{ mid, lon_range[1] };
            } else {
                lon_range = .{ lon_range[0], mid };
            }
        } else {
            const mid: f32 = (lat_range[0] + lat_range[1]) / 2;
            if (lat > mid) {
                ch = ch | bits[bit];
                lat_range = .{ mid, lat_range[1] };
            } else {
                lat_range = .{ lat_range[0], mid };
            }
        }
        even = !even;
        if (bit < 4) {
            bit += 1;
        } else {
            geohash[i] = base32[ch];
            i += 1;
            bit = 0;
            ch = 0;
        }
    }
    return geohash;
}

const DecodeError = error{
    InvalidDecodedCharacter,
};
