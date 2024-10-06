fn printf(format: *i8, _: u8) -> void;
fn memset(src: *void, value: u8, size: usize) -> void;
fn memcpy(dest: *void, src: *void, size: usize) -> void;

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

struct Packer {
	buffer: u8[2048];
	current: *u8;
	end: *u8;
	error: bool;

    fn add_int(i: isize) -> void {
        if this->error {
            return;
        }

        let next: *u8 = variableint_pack(this->current, i, this->end as usize - this->current as usize);
        if next == NULL {
            this->error = true;

            return;
        }

        this->current = next;
    }

    fn reset() -> void {
        this->error = false;
        this->current = this->buffer as *u8;
        this->end = this->current as *u8 + 2048;
    }


    fn add_raw(data: *void, size: usize) -> void {
        if this->error {
            return;
        }

        if this->current + size > this->end {
            this->error = true;

            return;
        }

        memcpy(this->current as *void, data, size);

        this->current = this->current + size;
    }

    fn size() -> usize {
        return this->current as usize - this->buffer as *u8 as usize;
    }

    fn add_string(str: *i8, limit: usize) -> void {
        if this->error {
            return;
        }

        if limit == 0 {
            limit = 2048;
        }

        while *str != 0 && limit != 0 {
            // We don't use utf-8 here
            let length: usize = 1;
            // Had to group because the parser thinks it's struct expression xd
            if (limit < length) {
                break;
            }
            // Ensure space for the null termination.
            if this->end as *u8 as usize - this->current as *u8 as usize < length + 1 {
                this->error = true;
                break;
            }

            // Why did I make char to be of type i8? :\
            *this->current = *str as u8;
            str = str + 1;
            this->current = this->current + 1;
            limit = limit - length;
        }

        *this->current = 0;
        this->current = this->current + 1;
    }
}

fn main() -> u8 {
    let packer: Packer = Packer{};
    memset(&packer as *void, 0, 4096);
    packer.reset();
    packer.add_int(69);

    return 0;
}
