#include "pack.h"
#include "text.h"

#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>

#define NTOKENS  ((uint32_t)2063592L)
#define MAX22    ((uint32_t)4194304L)
#define MAXGRID4 ((uint16_t)32400)

int32_t pack28(const char* callsign);
uint32_t ft8_callsign_hash(const char* callsign, int bits);
void ft8_save_hash_call(const char* callsign);

static const char* kARRLSections[] = {
    "AB", "AK", "AL", "AR", "AZ", "BC", "CO", "CT", "DE", "EB",
    "EMA", "ENY", "EPA", "EWA", "GA", "GTA", "IA", "ID", "IL", "IN",
    "KS", "KY", "LA", "LAX", "MAR", "MB", "MDC", "ME", "MI", "MN",
    "MO", "MS", "MT", "NC", "ND", "NE", "NFL", "NH", "NL", "NLI",
    "NM", "NNJ", "NNY", "NT", "NTX", "NV", "OH", "OK", "ONE", "ONN",
    "ONS", "OR", "ORG", "PAC", "PR", "QC", "RI", "SB", "SC", "SCV",
    "SD", "SDG", "SF", "SFL", "SJV", "SK", "SNJ", "STX", "SV", "TN",
    "UT", "VA", "VI", "VT", "WCF", "WI", "WMA", "WNY", "WPA", "WTX",
    "WV", "WWA", "WY", "DX"
};

static const int kNumARRLSections = (int)(sizeof(kARRLSections) / sizeof(kARRLSections[0]));

static int parse_field_day_class(const char* token, int* transmitter_count, int* class_index)
{
    int length = strlen(token);
    int count;
    char class_char;

    if (length < 2 || length > 3)
    {
        return -1;
    }

    class_char = to_upper(token[length - 1]);
    if (class_char < 'A' || class_char > 'F')
    {
        return -1;
    }

    count = dd_to_int(token, length - 1);
    if (count < 1 || count > 32)
    {
        return -1;
    }

    *transmitter_count = count;
    *class_index = class_char - 'A';
    return 0;
}

static int find_arrl_section(const char* token)
{
    char section[4];
    int i;

    if (strlen(token) < 2 || strlen(token) > 3)
    {
        return -1;
    }

    for (i = 0; token[i] != 0 && i < 3; ++i)
    {
        section[i] = to_upper(token[i]);
    }
    section[i] = '\0';

    for (i = 0; i < kNumARRLSections; ++i)
    {
        if (equals(section, kARRLSections[i]))
        {
            return i;
        }
    }

    return -1;
}

static int pack77_field_day(const char* msg, uint8_t* b77)
{
    char msg_copy[64];
    char* token;
    char* tokens[5];
    int num_tokens = 0;
    int32_t n28a;
    int32_t n28b;
    int has_r = 0;
    int transmitter_count;
    int class_index;
    int section_index;
    int n3;
    int n4;
    int i;

    strncpy(msg_copy, msg, sizeof(msg_copy) - 1);
    msg_copy[sizeof(msg_copy) - 1] = '\0';

    token = strtok(msg_copy, " ");
    while (token != NULL && num_tokens < 5)
    {
        tokens[num_tokens++] = token;
        token = strtok(NULL, " ");
    }

    if (num_tokens != 4 && num_tokens != 5)
    {
        return -1;
    }

    if (num_tokens == 5)
    {
        if (!equals(tokens[2], "R"))
        {
            return -1;
        }
        has_r = 1;
    }

    if (parse_field_day_class(tokens[num_tokens - 2], &transmitter_count, &class_index) < 0)
    {
        return -1;
    }

    section_index = find_arrl_section(tokens[num_tokens - 1]);
    if (section_index < 0)
    {
        return -1;
    }

    n28a = pack28(tokens[0]);
    n28b = pack28(tokens[1]);
    if (n28a < 0 || n28b < 0)
    {
        return -1;
    }

    if (transmitter_count <= 16)
    {
        n3 = 3;
        n4 = transmitter_count - 1;
    }
    else
    {
        n3 = 4;
        n4 = transmitter_count - 17;
    }

    for (i = 0; i < 10; ++i)
    {
        b77[i] = 0;
    }

    b77[0] = (uint8_t)(n28a >> 20);
    b77[1] = (uint8_t)(n28a >> 12);
    b77[2] = (uint8_t)(n28a >> 4);
    b77[3] = (uint8_t)((n28a << 4) | (n28b >> 24));
    b77[4] = (uint8_t)(n28b >> 16);
    b77[5] = (uint8_t)(n28b >> 8);
    b77[6] = (uint8_t)(n28b);
    b77[7] = (uint8_t)((has_r << 7) | (n4 << 3) | class_index);
    b77[8] = (uint8_t)(section_index << 1);
    b77[9] = (uint8_t)((n3 << 6) & 0xC0);

    return 0;
}

static int is_bracketed_call(const char* callsign)
{
    size_t length = strlen(callsign);
    return length >= 3 && callsign[0] == '<' && callsign[length - 1] == '>';
}

static void strip_bracketed_call(const char* input, char* output, size_t output_size)
{
    size_t start = 0;
    size_t end = strlen(input);
    size_t i;

    memset(output, 0, output_size);

    if (is_bracketed_call(input))
    {
        start = 1;
        end -= 1;
    }

    if (end - start >= output_size)
    {
        end = start + output_size - 1;
    }

    for (i = start; i < end; ++i)
    {
        output[i - start] = to_upper(input[i]);
    }
    output[end - start] = '\0';
}

static uint64_t pack58_callsign(const char* callsign)
{
    uint64_t n58 = 0;
    char normalized[12];
    int i;

    strip_bracketed_call(callsign, normalized, sizeof(normalized));
    for (i = 0; i < 11; ++i)
    {
        char ch = (normalized[i] != '\0') ? normalized[i] : ' ';
        int idx = char_index(" 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ/", ch);
        if (idx < 0)
        {
            return UINT64_MAX;
        }
        n58 = n58 * 38 + (uint64_t)idx;
    }

    return n58;
}

static int pack77_nonstandard(const char* msg, uint8_t* b77)
{
    char msg_copy[64];
    char* tokens[4];
    int num_tokens = 0;
    char* token;
    uint32_t n12;
    uint64_t n58;
    uint8_t iflip = 0;
    uint8_t nrpt = 0;
    uint8_t icq = 0;
    const char* full_call = NULL;
    const char* hashed_call = NULL;
    const char* extra = NULL;

    strncpy(msg_copy, msg, sizeof(msg_copy) - 1);
    msg_copy[sizeof(msg_copy) - 1] = '\0';

    token = strtok(msg_copy, " ");
    while (token != NULL && num_tokens < 4)
    {
        tokens[num_tokens++] = token;
        token = strtok(NULL, " ");
    }
    if (token != NULL || num_tokens < 2)
    {
        return -1;
    }

    if (equals(tokens[0], "CQ"))
    {
        if (num_tokens != 2)
        {
            return -1;
        }

        full_call = tokens[1];
        icq = 1;
    }
    else
    {
        if (num_tokens > 3)
        {
            return -1;
        }
        extra = (num_tokens == 3) ? tokens[2] : NULL;
        if (extra != NULL)
        {
            if (equals(extra, "RRR"))
            {
                nrpt = 1;
            }
            else if (equals(extra, "RR73"))
            {
                nrpt = 2;
            }
            else if (equals(extra, "73"))
            {
                nrpt = 3;
            }
            else
            {
                return -1;
            }
        }

        if (is_bracketed_call(tokens[0]) && !is_bracketed_call(tokens[1]))
        {
            hashed_call = tokens[0];
            full_call = tokens[1];
            iflip = 0;
        }
        else if (!is_bracketed_call(tokens[0]) && is_bracketed_call(tokens[1]))
        {
            full_call = tokens[0];
            hashed_call = tokens[1];
            iflip = 1;
        }
        else if (pack28(tokens[0]) < 0 && pack28(tokens[1]) >= 0)
        {
            full_call = tokens[0];
            hashed_call = tokens[1];
            iflip = 1;
        }
        else if (pack28(tokens[1]) < 0 && pack28(tokens[0]) >= 0)
        {
            full_call = tokens[1];
            hashed_call = tokens[0];
            iflip = 0;
        }
        else
        {
            return -1;
        }
    }

    n58 = pack58_callsign(full_call);
    if (n58 == UINT64_MAX)
    {
        return -1;
    }

    if (icq == 0)
    {
        n12 = ft8_callsign_hash(hashed_call, 12);
        ft8_save_hash_call(hashed_call);
    }
    else
    {
        n12 = 0;
    }
    ft8_save_hash_call(full_call);

    b77[0] = (uint8_t)(n12 >> 4);
    b77[1] = (uint8_t)((n12 << 4) | ((n58 >> 54) & 0x0F));
    b77[2] = (uint8_t)(n58 >> 46);
    b77[3] = (uint8_t)(n58 >> 38);
    b77[4] = (uint8_t)(n58 >> 30);
    b77[5] = (uint8_t)(n58 >> 22);
    b77[6] = (uint8_t)(n58 >> 14);
    b77[7] = (uint8_t)(n58 >> 6);
    b77[8] = (uint8_t)(((n58 & 0x3F) << 2) | (iflip << 1) | (nrpt >> 1));
    b77[9] = (uint8_t)(((nrpt & 0x01) << 7) | (icq << 6) | (4 << 3));

    return 0;
}

// TODO: This is wasteful, should figure out something more elegant
const char A0[] = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ+-./?";
const char A1[] = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const char A2[] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const char A3[] = "0123456789";
const char A4[] = " ABCDEFGHIJKLMNOPQRSTUVWXYZ";

// Pack a special token, a 22-bit hash code, or a valid base call
// into a 28-bit integer.
int32_t pack28(const char* callsign)
{
    if (is_bracketed_call(callsign))
    {
        char inner_call[16];
        strip_bracketed_call(callsign, inner_call, sizeof(inner_call));
        ft8_save_hash_call(inner_call);
        return NTOKENS + ft8_callsign_hash(inner_call, 22);
    }

    // Check for special tokens first
    if (starts_with(callsign, "DE "))
        return 0;
    if (starts_with(callsign, "QRZ "))
        return 1;
    if (starts_with(callsign, "CQ "))
        return 2;

    if (starts_with(callsign, "CQ_"))
    {
        char modifier[5] = { ' ', ' ', ' ', ' ', '\0' };
        int len = 0;
        int32_t n28 = 0;

        while (len < 4 && callsign[3 + len] != ' ' && callsign[3 + len] != 0)
        {
            char ch = to_upper(callsign[3 + len]);
            if (char_index(A4, ch) < 0)
            {
                return -1;
            }
            modifier[len++] = ch;
        }

        for (len = 0; len < 4; ++len)
        {
            int idx = char_index(A4, modifier[len]);
            if (idx < 0)
            {
                return -1;
            }
            n28 = n28 * 27 + idx;
        }

        return 1003 + n28;
    }

    // TODO: Check for <...> callsign

    char c6[6] = { ' ', ' ', ' ', ' ', ' ', ' ' };

    int length = 0; // strlen(callsign);  // We will need it later
    while (callsign[length] != ' ' && callsign[length] != 0)
    {
        length++;
    }

    // Copy callsign to 6 character buffer
    if (starts_with(callsign, "3DA0") && length <= 7)
    {
        // Work-around for Swaziland prefix: 3DA0XYZ -> 3D0XYZ
        memcpy(c6, "3D0", 3);
        memcpy(c6 + 3, callsign + 4, length - 4);
    }
    else if (starts_with(callsign, "3X") && is_letter(callsign[2]) && length <= 7)
    {
        // Work-around for Guinea prefixes: 3XA0XYZ -> QA0XYZ
        memcpy(c6, "Q", 1);
        memcpy(c6 + 1, callsign + 2, length - 2);
    }
    else
    {
        if (is_digit(callsign[2]) && length <= 6)
        {
            // AB0XYZ
            memcpy(c6, callsign, length);
        }
        else if (is_digit(callsign[1]) && length <= 5)
        {
            // A0XYZ -> " A0XYZ"
            memcpy(c6 + 1, callsign, length);
        }
    }

    // Check for standard callsign
    int i0, i1, i2, i3, i4, i5;
    if ((i0 = char_index(A1, c6[0])) >= 0 && (i1 = char_index(A2, c6[1])) >= 0 && (i2 = char_index(A3, c6[2])) >= 0 && (i3 = char_index(A4, c6[3])) >= 0 && (i4 = char_index(A4, c6[4])) >= 0 && (i5 = char_index(A4, c6[5])) >= 0)
    {
        // This is a standard callsign
        int32_t n28 = i0;
        n28 = n28 * 36 + i1;
        n28 = n28 * 10 + i2;
        n28 = n28 * 27 + i3;
        n28 = n28 * 27 + i4;
        n28 = n28 * 27 + i5;
        return NTOKENS + MAX22 + n28;
    }

    //char text[13];
    //if (length > 13) return -1;

    // TODO:
    // Treat this as a nonstandard callsign: compute its 22-bit hash
    return -1;
}

// Check if a string could be a valid standard callsign or a valid
// compound callsign.
// Return base call "bc" and a logical "cok" indicator.
bool chkcall(const char* call, char* bc)
{
    int length = strlen(call); // n1=len_trim(w)
    if (length > 11)
        return false;
    if (0 != strchr(call, '.'))
        return false;
    if (0 != strchr(call, '+'))
        return false;
    if (0 != strchr(call, '-'))
        return false;
    if (0 != strchr(call, '?'))
        return false;
    if (length > 6 && 0 != strchr(call, '/'))
        return false;

    // TODO: implement suffix parsing (or rework?)

    return true;
}

uint16_t packgrid(const char* grid4)
{
    if (grid4 == 0)
    {
        // Two callsigns only, no report/grid
        return MAXGRID4 + 1;
    }

    // Take care of special cases
    if (equals(grid4, "RRR"))
        return MAXGRID4 + 2;
    if (equals(grid4, "RR73"))
        return MAXGRID4 + 3;
    if (equals(grid4, "73"))
        return MAXGRID4 + 4;

    // Check for standard 4 letter grid
    if (in_range(grid4[0], 'A', 'R') && in_range(grid4[1], 'A', 'R') && is_digit(grid4[2]) && is_digit(grid4[3]))
    {
        uint16_t igrid4 = (grid4[0] - 'A');
        igrid4 = igrid4 * 18 + (grid4[1] - 'A');
        igrid4 = igrid4 * 10 + (grid4[2] - '0');
        igrid4 = igrid4 * 10 + (grid4[3] - '0');
        return igrid4;
    }

    // Parse report: +dd / -dd / R+dd / R-dd
    // TODO: check the range of dd
    if (grid4[0] == 'R')
    {
        int dd = dd_to_int(grid4 + 1, 3);
        uint16_t irpt = 35 + dd;
        return (MAXGRID4 + irpt) | 0x8000; // ir = 1
    }
    else
    {
        int dd = dd_to_int(grid4, 3);
        uint16_t irpt = 35 + dd;
        return (MAXGRID4 + irpt); // ir = 0
    }

    return MAXGRID4 + 1;
}

// Pack Type 1 (Standard 77-bit message) and Type 2 (ditto, with a "/P" call)
int pack77_1(const char* msg, uint8_t* b77)
{
    char msg_copy[64];
    char* tokens[4];
    int num_tokens = 0;
    char* token;
    char cq_modifier[8];
    const char* call1;
    const char* call2;
    const char* extra = 0;

    strncpy(msg_copy, msg, sizeof(msg_copy) - 1);
    msg_copy[sizeof(msg_copy) - 1] = '\0';

    token = strtok(msg_copy, " ");
    while (token != 0 && num_tokens < 4)
    {
        tokens[num_tokens++] = token;
        token = strtok(0, " ");
    }

    if (token != 0 || num_tokens < 2)
    {
        return -1;
    }

    call1 = tokens[0];
    call2 = tokens[1];

    if (equals(tokens[0], "CQ") && num_tokens == 4)
    {
        snprintf(cq_modifier, sizeof(cq_modifier), "CQ_%s", tokens[1]);
        call1 = cq_modifier;
        call2 = tokens[2];
        extra = tokens[3];
    }
    else if (num_tokens == 3)
    {
        extra = tokens[2];
    }
    else if (num_tokens > 3)
    {
        return -1;
    }

    int32_t n28a = pack28(call1);
    int32_t n28b = pack28(call2);
    uint16_t igrid4;

    if (extra != 0)
    {
        igrid4 = packgrid(extra);
    }
    else
    {
        // Two callsigns, no grid/report
        igrid4 = packgrid(0);
    }

    if (n28a < 0 || n28b < 0)
    {
        if (extra == 0 || (n28a < 0 && n28b < 0))
        {
            return -1;
        }
        if (n28a < 0)
        {
            ft8_save_hash_call(call1);
            n28a = NTOKENS + ft8_callsign_hash(call1, 22);
        }
        if (n28b < 0)
        {
            ft8_save_hash_call(call2);
            n28b = NTOKENS + ft8_callsign_hash(call2, 22);
        }
    }

    uint8_t i3 = 1; // No suffix or /R

    // TODO: check for suffixes

    // Shift in ipa and ipb bits into n28a and n28b
    n28a <<= 1; // ipa = 0
    n28b <<= 1; // ipb = 0

    // Pack into (28 + 1) + (28 + 1) + (1 + 15) + 3 bits
    b77[0] = (n28a >> 21);
    b77[1] = (n28a >> 13);
    b77[2] = (n28a >> 5);
    b77[3] = (uint8_t)(n28a << 3) | (uint8_t)(n28b >> 26);
    b77[4] = (n28b >> 18);
    b77[5] = (n28b >> 10);
    b77[6] = (n28b >> 2);
    b77[7] = (uint8_t)(n28b << 6) | (uint8_t)(igrid4 >> 10);
    b77[8] = (igrid4 >> 2);
    b77[9] = (uint8_t)(igrid4 << 6) | (uint8_t)(i3 << 3);

    return 0;
}

void packtext77(const char* text, uint8_t* b77)
{
    int length = strlen(text);

    // Skip leading and trailing spaces
    while (*text == ' ' && *text != 0)
    {
        ++text;
        --length;
    }
    while (length > 0 && text[length - 1] == ' ')
    {
        --length;
    }

    // Clear the first 72 bits representing a long number
    for (int i = 0; i < 9; ++i)
    {
        b77[i] = 0;
    }

    // Now express the text as base-42 number stored
    // in the first 72 bits of b77
    for (int j = 0; j < 13; ++j)
    {
        // Multiply the long integer in b77 by 42
        uint16_t x = 0;
        for (int i = 8; i >= 0; --i)
        {
            x += b77[i] * (uint16_t)42;
            b77[i] = (x & 0xFF);
            x >>= 8;
        }

        // Get the index of the current char
        if (j < length)
        {
            int q = char_index(A0, text[j]);
            x = (q > 0) ? q : 0;
        }
        else
        {
            x = 0;
        }
        // Here we double each added number in order to have the result multiplied
        // by two as well, so that it's a 71 bit number left-aligned in 72 bits (9 bytes)
        x <<= 1;

        // Now add the number to our long number
        for (int i = 8; i >= 0; --i)
        {
            if (x == 0)
                break;
            x += b77[i];
            b77[i] = (x & 0xFF);
            x >>= 8;
        }
    }

    // Set n3=0 (bits 71..73) and i3=0 (bits 74..76)
    b77[8] &= 0xFE;
    b77[9] &= 0x00;
}

int pack77(const char* msg, uint8_t* c77)
{
    if (0 == pack77_field_day(msg, c77))
    {
        return 0;
    }

    // Check Type 1 (Standard 77-bit message) or Type 2, with optional "/P"
    if (0 == pack77_nonstandard(msg, c77))
    {
        return 0;
    }

    if (0 == pack77_1(msg, c77))
    {
        return 0;
    }

    // TODO:
    // Check 0.5 (telemetry)

    // Check Type 4 (One nonstandard call and one hashed call)

    // Default to free text
    // i3=0 n3=0
    packtext77(msg, c77);
    return 0;
}

#ifdef UNIT_TEST

#include <iostream>

bool test1()
{
    const char* inputs[] = {
        "",
        " ",
        "ABC",
        "A9",
        "L9A",
        "L7BC",
        "L0ABC",
        "LL3JG",
        "LL3AJG",
        "CQ ",
        0
    };

    for (int i = 0; inputs[i]; ++i)
    {
        int32_t result = ft8_v2::pack28(inputs[i]);
        printf("pack28(\"%s\") = %d\n", inputs[i], result);
    }

    return true;
}

bool test2()
{
    const char* inputs[] = {
        "CQ LL3JG",
        "CQ LL3JG KO26",
        "L0UAA LL3JG KO26",
        "L0UAA LL3JG +02",
        "L0UAA LL3JG RRR",
        "L0UAA LL3JG 73",
        0
    };

    for (int i = 0; inputs[i]; ++i)
    {
        uint8_t result[10];
        int rc = ft8_v2::pack77_1(inputs[i], result);
        printf("pack77_1(\"%s\") = %d\t[", inputs[i], rc);
        for (int j = 0; j < 10; ++j)
        {
            printf("%02x ", result[j]);
        }
        printf("]\n");
    }

    return true;
}

int main()
{
    test1();
    test2();
    return 0;
}

#endif
