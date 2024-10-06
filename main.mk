fn printf(format: *i8, _: u8) -> void;
fn memset(src: *void, value: u8, size: usize) -> void;
fn memcpy(dest: *void, src: *void, size: usize) -> void;
fn socket(domain: u32, type: u32, protocol: u32) -> i32;
fn sendto(fd: i32, buf: *void, n: usize, flags: u32, addr: *SockAddr, addr_len: usize) -> isize;
fn inet_addr(host: *i8) -> u32;
fn htons(host: u16) -> u16;
fn close(fd: i32) -> i32;

struct SockAddr {
    family: u16;
    port: u16;
    addr: u32;
    _: u8; // padding
}

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

struct NetChunk {
	client_id: u32;
	address: *void;
	flags: u32;
	data_size: u32;
	data: *void;
}

struct NetPacketConstruct {
	flags: u32;
	ack: u32;
	num_chunks: u32;
	data_size: u32;
	chunk_data: u8[1394];
}

struct NetConnection {
    ack: usize;
    sock_addr: SockAddr;

    fn send_connect(fd: i32) -> void {
        let MAGIC: u8[4] = [84, 75, 69, 78];

        // FIXME: add syntax to call methods using -> operator
        (*this).send_ctrl_msg(fd, 1, MAGIC as *u8 as *void, 4 as u32, 1 as u32);
    }

    fn send_ctrl_msg(fd: i32, ctrl_msg: u8, extra: *void, extra_size: u32, token: u32) -> void {
        // 4 - NET_PACKETFLAG_CONTROL
        let construct: NetPacketConstruct = NetPacketConstruct {
            flags: 4,
            ack: this->ack,
            num_chunks: 0,
            data_size: 1 + extra_size,
        };

        construct.chunk_data[0] = ctrl_msg;

        if extra != NULL {
            memcpy(&construct.chunk_data[1] as *void, extra, extra_size as usize);
        }

        (*this).send_packet(fd, &construct, token);
    }

    fn send_packet(fd: i32, packet: *NetPacketConstruct, token: u32) -> void {
        let buffer: u8[1400];

        memcpy((packet->chunk_data as *u8 + packet->data_size as usize) as *void, &token as *void, 4);
		packet->data_size = packet->data_size + 4;

        // NOTE: if you use `packet->chunk_data as *void`, it shows absurd error message xd
		memcpy(&buffer[3] as *void, packet->chunk_data as *u8 as *void, packet->data_size as usize);
        // 32 - NET_PACKETFLAG_COMPRESSION
		packet->flags = packet->flags & ~32;

        // That's a lot of casts btw :\
        buffer[0] = (((packet->flags << 2) & 252) | ((packet->ack >> 8) & 3)) as u8;
		buffer[1] = (packet->ack & 255) as u8;
		buffer[2] = packet->num_chunks as u8;

        sendto(fd, buffer as *u8 as *void, packet->data_size as usize, 0 as u32, &this->sock_addr, 16 as usize);
    }
}

struct Client {
    net_conn: NetConnection;
}

fn main() -> u8 {
    // (AF_INET, SOCK_DGRAM, 0)
    let fd: i32 = socket(2, 2, 0);
    if fd < 0 {
        printf("Failed to get socket fd", 0);
        return 1;
    } else {
        printf("Created socket successfully", 0);
    }

    let client: Client = Client {
        net_conn: NetConnection {
            ack: 0,
            sock_addr: SockAddr {
                family: 2,
                addr: inet_addr("127.0.0.1"),
                port: htons(42069),
            },
        },
    };

    client.net_conn.send_connect(fd);

    return 0;
}
