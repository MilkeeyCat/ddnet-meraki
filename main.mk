fn printf(format: *i8) -> void;

fn variableint_pack(dest: *u8, i: isize, dest_size: usize) -> *u8 {
    if dest_size < 0 || dest_size == 0 {
        return NULL;
    }

    dest_size = dest_size - 1;
    *dest = 0;

    if i < 0 {
        *dest = *dest | 64;
        i = ~i;
    }

    *dest = *dest | (i & 63) as u8;
    i = i >> 6;
    while i > 0 {
        if dest_size < 0 || dest_size == 0 {
            return NULL;
        }

        *dest = *dest | 128;
        dest_size = dest_size - 1;
        dest = dest + 1;
        *dest = (i & 127) as u8;
        i = i >> 7;
    }

    dest = dest + 1;

    return dest;
}

fn main() -> u8 {
    printf("Hello tees!\n");

    return 0;
}
