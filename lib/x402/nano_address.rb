# frozen_string_literal: true

module X402
  # Validates Nano (XNO) account addresses.
  #
  # A Nano address is "nano_" (or the legacy "xrb_") followed by 60 base32
  # characters: 52 encode the 256-bit Ed25519 public key (padded with 4 zero
  # bits) and 8 encode a 40-bit checksum, which is the 5-byte Blake2b digest of
  # the public key with its bytes reversed.
  #
  # Ruby's OpenSSL binding only exposes Blake2b-512, and a 5-byte Blake2b digest
  # is not a truncation of it (the output length is part of the parameter
  # block), so a small Blake2b (RFC 7693) is included here.
  module NanoAddress
    ALPHABET = "13456789abcdefghijkmnopqrstuwxyz"
    PREFIXES = %w[nano_ xrb_].freeze
    # The first character carries the 4 zero padding bits plus the key's top
    # bit, so it can only be "1" or "3"; anything else is a key over 256 bits.
    BODY_PATTERN = /\A[13][#{ALPHABET}]{59}\z/

    class << self
      def valid?(address)
        !public_key(address).nil?
      end

      # Returns the 32-byte public key as uppercase hex, or nil when the
      # address is malformed or its checksum does not match.
      def public_key(address)
        return nil unless address.is_a?(String)

        prefix = PREFIXES.find { |p| address.start_with?(p) }
        return nil unless prefix

        body = address.delete_prefix(prefix)
        return nil unless body.match?(BODY_PATTERN)

        key = [decode_base32(body[0, 52]).to_s(16).rjust(64, "0")].pack("H*")
        checksum = decode_base32(body[52, 8])
        expected = Blake2b.digest(key, 5).reverse.unpack1("H*").to_i(16)
        return nil unless checksum == expected

        key.unpack1("H*").upcase
      end

      private

      def decode_base32(chars)
        chars.each_char.reduce(0) { |acc, c| (acc << 5) | ALPHABET.index(c) }
      end
    end

    # Minimal Blake2b (RFC 7693), unkeyed, digest length 1..64 bytes.
    module Blake2b
      MASK = 0xFFFFFFFFFFFFFFFF
      IV = [
        0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
        0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179
      ].freeze
      SIGMA = [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
        [14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3],
        [11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4],
        [7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8],
        [9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13],
        [2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9],
        [12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11],
        [13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10],
        [6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5],
        [10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0]
      ].freeze

      class << self
        def digest(data, out_len = 64)
          raise ArgumentError, "digest length must be 1..64" unless (1..64).cover?(out_len)

          h = IV.dup
          h[0] ^= 0x01010000 ^ out_len
          data = data.b
          blocks = [(data.bytesize + 127) / 128, 1].max
          blocks.times do |i|
            chunk = data.byteslice(i * 128, 128)
            last = i == blocks - 1
            counter = last ? data.bytesize : (i + 1) * 128
            compress(h, chunk.ljust(128, "\0").unpack("Q<16"), counter, last)
          end
          h.pack("Q<8").byteslice(0, out_len)
        end

        private

        def compress(h, m, counter, last)
          v = h + IV
          v[12] ^= counter & MASK
          v[13] ^= counter >> 64
          v[14] ^= MASK if last
          12.times do |round|
            s = SIGMA[round % 10]
            mix(v, 0, 4, 8, 12, m[s[0]], m[s[1]])
            mix(v, 1, 5, 9, 13, m[s[2]], m[s[3]])
            mix(v, 2, 6, 10, 14, m[s[4]], m[s[5]])
            mix(v, 3, 7, 11, 15, m[s[6]], m[s[7]])
            mix(v, 0, 5, 10, 15, m[s[8]], m[s[9]])
            mix(v, 1, 6, 11, 12, m[s[10]], m[s[11]])
            mix(v, 2, 7, 8, 13, m[s[12]], m[s[13]])
            mix(v, 3, 4, 9, 14, m[s[14]], m[s[15]])
          end
          8.times { |i| h[i] ^= v[i] ^ v[i + 8] }
        end

        def mix(v, a, b, c, d, x, y)
          v[a] = (v[a] + v[b] + x) & MASK
          v[d] = rotr(v[d] ^ v[a], 32)
          v[c] = (v[c] + v[d]) & MASK
          v[b] = rotr(v[b] ^ v[c], 24)
          v[a] = (v[a] + v[b] + y) & MASK
          v[d] = rotr(v[d] ^ v[a], 16)
          v[c] = (v[c] + v[d]) & MASK
          v[b] = rotr(v[b] ^ v[c], 63)
        end

        def rotr(x, n)
          ((x >> n) | (x << (64 - n))) & MASK
        end
      end
    end
  end
end
