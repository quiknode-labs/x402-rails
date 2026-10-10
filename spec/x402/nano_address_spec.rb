# frozen_string_literal: true

RSpec.describe X402::NanoAddress do
  # Nano genesis account. Public key cross-checked with Python's hashlib.blake2b.
  let(:genesis) { "nano_3t6k35gi95xu6tergt6p69ck76ogmitsa8mnijtpxm9fkcm736xtoncuohr3" }
  let(:genesis_key) { "E89208DD038FBB269987689621D52292AE9C35941A7484756ECCED92A65093BA" }
  # All-zero public key (the well-known burn address).
  let(:burn) { "nano_1111111111111111111111111111111111111111111111111111hifc8npp" }

  describe ".public_key" do
    it "decodes the genesis account" do
      expect(described_class.public_key(genesis)).to eq(genesis_key)
    end

    it "decodes the all-zero key" do
      expect(described_class.public_key(burn)).to eq("0" * 64)
    end

    it "accepts the legacy xrb_ prefix" do
      expect(described_class.public_key(genesis.sub("nano_", "xrb_"))).to eq(genesis_key)
    end
  end

  describe ".valid?" do
    it "accepts valid addresses" do
      expect(described_class.valid?(genesis)).to be true
      expect(described_class.valid?(burn)).to be true
    end

    it "rejects a wrong checksum" do
      expect(described_class.valid?("#{genesis[0..-2]}1")).to be false
    end

    it "rejects a changed public key character" do
      tampered = genesis.dup
      tampered[10] = tampered[10] == "a" ? "b" : "a"
      expect(described_class.valid?(tampered)).to be false
    end

    it "rejects a missing or unknown prefix" do
      expect(described_class.valid?(genesis.delete_prefix("nano_"))).to be false
      expect(described_class.valid?(genesis.sub("nano_", "ban_"))).to be false
    end

    it "rejects the wrong length" do
      expect(described_class.valid?(genesis[0..-2])).to be false
      expect(described_class.valid?("#{genesis}1")).to be false
    end

    it "rejects characters outside the Nano alphabet" do
      %w[0 2 l v].each do |c|
        bad = genesis.dup
        bad[20] = c
        expect(described_class.valid?(bad)).to be false
      end
      expect(described_class.valid?(genesis.upcase)).to be false
    end

    it "rejects a key over 256 bits" do
      expect(described_class.valid?(genesis.sub("nano_3", "nano_4"))).to be false
    end

    it "rejects EVM addresses, nil and non-strings" do
      expect(described_class.valid?("0x036CbD53842c5426634e7929541eC2318f3dCF7e")).to be false
      expect(described_class.valid?(nil)).to be false
      expect(described_class.valid?(12_345)).to be false
    end
  end

  describe X402::NanoAddress::Blake2b do
    # Reference values from Python's hashlib.blake2b.
    it "matches the RFC 7693 test vector for 'abc'" do
      expect(described_class.digest("abc").unpack1("H*")).to eq(
        "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d1" \
        "7d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923"
      )
    end

    it "uses the output length as a parameter, not a truncation" do
      expect(described_class.digest("abc", 5).unpack1("H*")).to eq("44229fc0ef")
    end

    it "handles empty and multi-block input" do
      expect(described_class.digest("", 5).unpack1("H*")).to eq("7d64c5272e")
      expect(described_class.digest("a" * 129, 5).unpack1("H*")).to eq("db81508574")
      expect(described_class.digest("a" * 128, 32).unpack1("H*")).to eq(
        "ae2aa48507885c4c950fb809b2076f959cde9f8ea6da260d9a3587df33dac450"
      )
    end

    it "rejects an out-of-range digest length" do
      expect { described_class.digest("abc", 0) }.to raise_error(ArgumentError)
      expect { described_class.digest("abc", 65) }.to raise_error(ArgumentError)
    end
  end
end
