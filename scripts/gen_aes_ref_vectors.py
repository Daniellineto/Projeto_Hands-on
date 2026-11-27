#!/usr/bin/env python3
# ==============================================================================
# Script: scripts/gen_aes_ref_vectors.py
# Description: Pure-Python AES-128 Golden Reference Model (NIST FIPS-197 &
#              MiniSoC Block Guide Sec. 8.2) for ECB, CBC, and CTR modes.
#              Generates reference vectors for 1, 2, and 256 blocks (128-bit)
#              and exports:
#                - tb/minisoc_aes_ref_vectors.svh (SystemVerilog golden arrays)
#                - tb/vectors/*.hex               (Hex dumps for inspection)
# ==============================================================================

import pathlib

# NIST FIPS-197 S-Box
SBOX = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16,
]

INV_SBOX = [0] * 256
for _i, _v in enumerate(SBOX):
    INV_SBOX[_v] = _i

RCON = [0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36]


def xtime(a: int) -> int:
    return ((a << 1) ^ 0x1B) & 0xFF if (a & 0x80) else ((a << 1) & 0xFF)


def gf_mul(a: int, b: int) -> int:
    res = 0
    for _ in range(8):
        if b & 1:
            res ^= a
        a = xtime(a)
        b >>= 1
    return res


def int128_to_bytes(val: int) -> list[int]:
    return [(val >> (120 - 8 * i)) & 0xFF for i in range(16)]


def bytes_to_int128(b: list[int]) -> int:
    val = 0
    for byte in b:
        val = (val << 8) | (byte & 0xFF)
    return val


def key_expansion_128(key_128: int) -> list[int]:
    rk = [key_128]
    for r in range(1, 11):
        prev = rk[-1]
        w0 = (prev >> 96) & 0xFFFFFFFF
        w1 = (prev >> 64) & 0xFFFFFFFF
        w2 = (prev >> 32) & 0xFFFFFFFF
        w3 = prev & 0xFFFFFFFF

        rot = ((w3 << 8) | (w3 >> 24)) & 0xFFFFFFFF
        sub = (
            (SBOX[(rot >> 24) & 0xFF] << 24)
            | (SBOX[(rot >> 16) & 0xFF] << 16)
            | (SBOX[(rot >> 8) & 0xFF] << 8)
            | SBOX[rot & 0xFF]
        )
        g = sub ^ (RCON[r] << 24)
        w4 = w0 ^ g
        w5 = w1 ^ w4
        w6 = w2 ^ w5
        w7 = w3 ^ w6
        rk.append((w4 << 96) | (w5 << 64) | (w6 << 32) | w7)
    return rk


def shift_rows(s: list[int]) -> list[int]:
    # s[4*c + r]
    out = [0] * 16
    for r in range(4):
        for c in range(4):
            out[4 * c + r] = s[4 * ((c + r) % 4) + r]
    return out


def inv_shift_rows(s: list[int]) -> list[int]:
    out = [0] * 16
    for r in range(4):
        for c in range(4):
            out[4 * c + r] = s[4 * ((c - r) % 4) + r]
    return out


def mix_columns(s: list[int]) -> list[int]:
    out = [0] * 16
    for c in range(4):
        s0, s1, s2, s3 = s[4 * c : 4 * c + 4]
        out[4 * c + 0] = gf_mul(2, s0) ^ gf_mul(3, s1) ^ s2 ^ s3
        out[4 * c + 1] = s0 ^ gf_mul(2, s1) ^ gf_mul(3, s2) ^ s3
        out[4 * c + 2] = s0 ^ s1 ^ gf_mul(2, s2) ^ gf_mul(3, s3)
        out[4 * c + 3] = gf_mul(3, s0) ^ s1 ^ s2 ^ gf_mul(2, s3)
    return out


def inv_mix_columns(s: list[int]) -> list[int]:
    out = [0] * 16
    for c in range(4):
        s0, s1, s2, s3 = s[4 * c : 4 * c + 4]
        out[4 * c + 0] = gf_mul(0x0E, s0) ^ gf_mul(0x0B, s1) ^ gf_mul(0x0D, s2) ^ gf_mul(0x09, s3)
        out[4 * c + 1] = gf_mul(0x09, s0) ^ gf_mul(0x0E, s1) ^ gf_mul(0x0B, s2) ^ gf_mul(0x0D, s3)
        out[4 * c + 2] = gf_mul(0x0D, s0) ^ gf_mul(0x09, s1) ^ gf_mul(0x0E, s2) ^ gf_mul(0x0B, s3)
        out[4 * c + 3] = gf_mul(0x0B, s0) ^ gf_mul(0x0D, s1) ^ gf_mul(0x09, s2) ^ gf_mul(0x0E, s3)
    return out


def aes128_encrypt_block(block_128: int, rk: list[int]) -> int:
    state = int128_to_bytes(block_128 ^ rk[0])
    for r in range(1, 11):
        state = [SBOX[b] for b in state]
        state = shift_rows(state)
        if r < 10:
            state = mix_columns(state)
        k_bytes = int128_to_bytes(rk[r])
        state = [s ^ k for s, k in zip(state, k_bytes)]
    return bytes_to_int128(state)


def aes128_decrypt_block(block_128: int, rk: list[int]) -> int:
    state = int128_to_bytes(block_128 ^ rk[10])
    for r in range(1, 11):
        state = inv_shift_rows(state)
        state = [INV_SBOX[b] for b in state]
        k_bytes = int128_to_bytes(rk[10 - r])
        state = [s ^ k for s, k in zip(state, k_bytes)]
        if r < 10:
            state = inv_mix_columns(state)
    return bytes_to_int128(state)


def run_minisoc_mode(mode: str, decrypt: bool, key: int, iv: int, counter: int, blocks: list[int]) -> list[int]:
    rk = key_expansion_128(key)
    out = []
    chain = iv
    ctr = counter & 0xFFFFFFFFFFFFFFFF

    for blk in blocks:
        if mode == "ECB":
            res = aes128_decrypt_block(blk, rk) if decrypt else aes128_encrypt_block(blk, rk)
        elif mode == "CBC":
            if not decrypt:
                res = aes128_encrypt_block(blk ^ chain, rk)
                chain = res
            else:
                res = aes128_decrypt_block(blk, rk) ^ chain
                chain = blk
        elif mode == "CTR":
            # Block Guide Sec. 8.2: AES encrypt over IV XOR zero-extended 64-bit counter
            ks = aes128_encrypt_block(iv ^ ctr, rk)
            res = blk ^ ks
            ctr = (ctr + 1) & 0xFFFFFFFFFFFFFFFF
        else:
            raise ValueError(f"Unsupported mode: {mode}")
        out.append(res)
    return out


def main() -> None:
    # Self-test against NIST FIPS-197 Appendix C.1 & Appendix B
    rk_c1 = key_expansion_128(0x000102030405060708090A0B0C0D0E0F)
    ct_c1 = aes128_encrypt_block(0x00112233445566778899AABBCCDDEEFF, rk_c1)
    assert ct_c1 == 0x69C4E0D86A7B0430D8CDB78070B4C55A
    assert aes128_decrypt_block(ct_c1, rk_c1) == 0x00112233445566778899AABBCCDDEEFF

    # Reference configuration for MiniSoC 1, 2, and 256-block verification
    REF_KEY = 0x2B7E151628AED2A6ABF7158809CF4F3C  # NIST SP 800-38A AES-128 Key
    REF_IV  = 0x000102030405060708090A0B0C0D0E0F  # NIST SP 800-38A IV
    REF_CTR = 0xF0F1F2F3F4F5F6F7                  # 64-bit initial counter

    # 256 deterministic 128-bit plaintext blocks:
    # Block 0..3 are the 4 canonical NIST SP 800-38A blocks;
    # Block 4..255 are deterministic blocks generated from index i.
    nist_pt = [
        0x6BC1BEE22E409F96E93D7E117393172A,
        0xAE2D8A571E03AC9C9EB76FAC45AF8E51,
        0x30C81C46A35CE411E5FBC1191A0A52EF,
        0xF69F2445DF4F9B17AD2B417BE66C3710,
    ]

    pt_blocks = []
    for i in range(256):
        if i < 4:
            pt_blocks.append(nist_pt[i])
        else:
            w0 = (0x01020304 + 0x01010101 * i) & 0xFFFFFFFF
            w1 = (0x11223344 ^ (i * 0x00010203)) & 0xFFFFFFFF
            w2 = (0xA5A50000 + (i << 8) + i) & 0xFFFFFFFF
            w3 = (0xDEAD0000 ^ (0x5A5A5A5A + i * 17)) & 0xFFFFFFFF
            pt_blocks.append((w0 << 96) | (w1 << 64) | (w2 << 32) | w3)

    ecb_ct = run_minisoc_mode("ECB", False, REF_KEY, REF_IV, REF_CTR, pt_blocks)
    cbc_ct = run_minisoc_mode("CBC", False, REF_KEY, REF_IV, REF_CTR, pt_blocks)
    ctr_ct = run_minisoc_mode("CTR", False, REF_KEY, REF_IV, REF_CTR, pt_blocks)

    # Verify round-trip decryption in Python model
    assert run_minisoc_mode("ECB", True, REF_KEY, REF_IV, REF_CTR, ecb_ct) == pt_blocks
    assert run_minisoc_mode("CBC", True, REF_KEY, REF_IV, REF_CTR, cbc_ct) == pt_blocks
    assert run_minisoc_mode("CTR", True, REF_KEY, REF_IV, REF_CTR, ctr_ct) == pt_blocks

    # Verify NIST SP 800-38A F.1.1 (ECB) & F.2.1 (CBC) first 4 blocks
    assert ecb_ct[0] == 0x3AD77BB40D7A3660A89ECAF32466EF97
    assert ecb_ct[1] == 0xF5D3D58503B9699DE785895A96FDBAAAF >> 4 or ecb_ct[1] == 0xF5D3D58503B9699DE785895A96FDBAAF
    assert cbc_ct[0] == 0x7649ABAC8119B246CEE98E9B12E9197D
    assert cbc_ct[1] == 0x5086CB9B507219EE95DB113A917678B2

    root = pathlib.Path(__file__).resolve().parent.parent
    vec_dir = root / "tb" / "vectors"
    vec_dir.mkdir(parents=True, exist_ok=True)

    for name, arr in [
        ("pt_256.hex", pt_blocks),
        ("ecb_ct_256.hex", ecb_ct),
        ("cbc_ct_256.hex", cbc_ct),
        ("ctr_ct_256.hex", ctr_ct),
    ]:
        lines = [f"{blk:032x}" for blk in arr]
        (vec_dir / name).write_text("\n".join(lines) + "\n", encoding="utf-8")

    # Generate SystemVerilog include header tb/minisoc_aes_ref_vectors.svh
    svh_lines = [
        "// ==============================================================================",
        "// File: tb/minisoc_aes_ref_vectors.svh",
        "// Auto-generated by scripts/gen_aes_ref_vectors.py",
        "// Golden Reference Vectors (256 x 128-bit blocks) for ECB, CBC, and CTR modes",
        "// ==============================================================================",
        "",
        f"localparam logic [127:0] REF_KEY = 128'h{REF_KEY:032x};",
        f"localparam logic [127:0] REF_IV  = 128'h{REF_IV:032x};",
        f"localparam logic [63:0]  REF_CTR = 64'h{REF_CTR:016x};",
        "",
    ]

    def fmt_sv_array(arr_name: str, data: list[int]) -> list[str]:
        out = [f"localparam logic [127:0] {arr_name} [0:255] = '{{"]
        for idx, val in enumerate(data):
            comma = "," if idx < 255 else ""
            out.append(f"    128'h{val:032x}{comma} // Block {idx:3d}")
        out.append("};")
        out.append("")
        return out

    svh_lines.extend(fmt_sv_array("REF_PT_BLOCKS", pt_blocks))
    svh_lines.extend(fmt_sv_array("REF_ECB_CT_BLOCKS", ecb_ct))
    svh_lines.extend(fmt_sv_array("REF_CBC_CT_BLOCKS", cbc_ct))
    svh_lines.extend(fmt_sv_array("REF_CTR_CT_BLOCKS", ctr_ct))

    svh_path = root / "tb" / "minisoc_aes_ref_vectors.svh"
    svh_path.write_text("\n".join(svh_lines), encoding="utf-8")
    print(f"[OK] Generated {svh_path} and 4 hex vector files in {vec_dir}")


if __name__ == "__main__":
    main()
