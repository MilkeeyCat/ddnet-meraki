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

fn variableint_unpack(src: *u8, dest: *isize, size: usize) -> *u8 {
	if size < 0 || size == 0 {
        return NULL;
    }

	let sign: u8 = (*src >> 6) & 1;
	*dest = (*src & 63) as isize;
	size = size - 1;

	let masks: u8[4] = [127, 127, 127, 15];
	let shifts: u8[4] = [6, 6 + 7, 6 + 7 + 7, 6 + 7 + 7 + 7];

	for let i: u8 = 0; i < 4; i = i + 1 {
		if (*src & 128) == 0 {
            break;
        }
		if(size < 0 || size == 0) {
            return NULL;
        }

		size = size - 1;
		src = src + 1;
		*dest = *dest | ((*src & masks[i]) << shifts[i]) as isize;
	}

	src = src + 1;
    if sign != 0 {
        *dest = ~(*dest);
    }

	return src;
}

fn main() -> u8 {
    printf("Hello tees!\n");

    return 0;
}
