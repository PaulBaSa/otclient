/*
 * In-memory I/O API for minizip.
 * Allows reading zip files from a memory buffer via fill_memory_filefunc().
 *
 * Based on the public-domain minizip companion originally by Nathan Moinvaziri.
 */

#pragma once

#include <minizip/ioapi.h>
#include <cstdlib>
#include <cstring>

typedef struct ourmemory_s {
    char  *base;   /* pointer to the start of the memory buffer */
    uLong  size;   /* total size of the buffer */
    uLong  tell;   /* current read position */
    int    error;  /* non-zero after a failed operation */
} ourmemory_t;

static voidpf ZCALLBACK mem_open(voidpf opaque, const char* /*filename*/, int /*mode*/) {
    ourmemory_t* mem = (ourmemory_t*)opaque;
    if (!mem) return nullptr;
    mem->tell  = 0;
    mem->error = 0;
    return opaque;
}

static uLong ZCALLBACK mem_read(voidpf /*opaque*/, voidpf stream, void* buf, uLong size) {
    ourmemory_t* mem = (ourmemory_t*)stream;
    uLong remaining = mem->size - mem->tell;
    if (size > remaining) size = remaining;
    if (size == 0) return 0;
    std::memcpy(buf, mem->base + mem->tell, (size_t)size);
    mem->tell += size;
    return size;
}

static uLong ZCALLBACK mem_write(voidpf /*opaque*/, voidpf stream, const void* buf, uLong size) {
    ourmemory_t* mem = (ourmemory_t*)stream;
    uLong remaining = mem->size - mem->tell;
    if (size > remaining) size = remaining;
    if (size == 0) return 0;
    std::memcpy(mem->base + mem->tell, buf, (size_t)size);
    mem->tell += size;
    return size;
}

static long ZCALLBACK mem_tell(voidpf /*opaque*/, voidpf stream) {
    return (long)((ourmemory_t*)stream)->tell;
}

static long ZCALLBACK mem_seek(voidpf /*opaque*/, voidpf stream, uLong offset, int origin) {
    ourmemory_t* mem = (ourmemory_t*)stream;
    uLong pos;
    switch (origin) {
        case ZLIB_FILEFUNC_SEEK_CUR: pos = mem->tell + offset; break;
        case ZLIB_FILEFUNC_SEEK_END: pos = mem->size + offset; break;
        case ZLIB_FILEFUNC_SEEK_SET: pos = offset;             break;
        default: return -1;
    }
    if ((long)pos < 0) return -1;
    mem->tell = pos;
    return 0;
}

static int ZCALLBACK mem_close(voidpf /*opaque*/, voidpf /*stream*/) { return 0; }

static int ZCALLBACK mem_error(voidpf /*opaque*/, voidpf stream) {
    return ((ourmemory_t*)stream)->error;
}

inline void fill_memory_filefunc(zlib_filefunc_def* pzlib_filefunc_def, ourmemory_t* ourmem) {
    pzlib_filefunc_def->zopen_file  = mem_open;
    pzlib_filefunc_def->zread_file  = mem_read;
    pzlib_filefunc_def->zwrite_file = mem_write;
    pzlib_filefunc_def->ztell_file  = mem_tell;
    pzlib_filefunc_def->zseek_file  = mem_seek;
    pzlib_filefunc_def->zclose_file = mem_close;
    pzlib_filefunc_def->zerror_file = mem_error;
    pzlib_filefunc_def->opaque      = ourmem;
}
