// Isolated AArch64 loader execution with ALL Apple/dyld calls intercepted.
// This is NOT an iOS load test, a substrate test, or an actual dlopen of iOS code.
#define _GNU_SOURCE
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>

static unsigned char *image;
static int enabled, high, found, success, pac, normalize_auth, calls[4];
static void *const pool_token=(void *)(uintptr_t)0x12345000;
static void *pool_push(void) { calls[0]++; return pool_token; }
static void pool_pop(void *p) { assert(p==pool_token); calls[3]++; }
static void settings(void) { image[0x10494]=(unsigned char)enabled; image[0x10497]=(unsigned char)high; }
static void *mock_open(const char *path, int mode) {
    assert(!strcmp(path,"@loader_path/RelaxTuneProMotion120.dylib"));
    assert(mode==6); calls[2]++; return success ? (void *)(uintptr_t)0x98765000 : NULL;
}
static void *mock_sym(void *handle,const char *name) {
    assert(handle==(void *)(intptr_t)-2); assert(!strcmp(name,"dlopen")); calls[1]++;
    if(!found)return NULL;
    void *p=(void *)mock_open;
    if(pac && !normalize_auth) __asm__ volatile("paciza %0" : "+r"(p));
    return p;
}
static void trampoline(size_t off,void *fn) {
    // Original imports have 12/16-byte strides: use separate 16-byte islands.
    static size_t island=0x2000;
    const uint32_t code[]={0x58000050,0xd61f0200};
    uint32_t branch=0x14000000u|((uint32_t)(((intptr_t)island-(intptr_t)off)/4)&0x3ffffffu);
    memcpy(image+off,&branch,4);memcpy(image+island,code,8);memcpy(image+island+8,&fn,8);island+=32;
}
int main(int argc,char **argv) {
    assert(argc==3);normalize_auth=atoi(argv[2])==2;pac=atoi(argv[2])!=0;FILE *f=fopen(argv[1],"rb");assert(f);
    assert(!fseek(f,0,SEEK_END));long size=ftell(f);assert(size>0x10498);rewind(f);
    size_t allocated=((size_t)size+4095)&~(size_t)4095;
    image=mmap(NULL,allocated,PROT_READ|PROT_WRITE,MAP_ANONYMOUS|MAP_PRIVATE,-1,0);assert(image!=MAP_FAILED);
    assert(fread(image,1,(size_t)size,f)==(size_t)size);fclose(f);
    trampoline(pac?0x810c:0x7c10,(void *)settings);
    trampoline(pac?0x8778:0x81fc,(void *)mock_sym);
    trampoline(pac?0x87c8:0x8238,(void *)pool_push);
    trampoline(pac?0x87b8:0x822c,(void *)pool_pop);
    if(normalize_auth) { // TEST COPY ONLY; delivered dylib remains authenticated.
        const uint32_t blraaz=0xd63f0a1f,blr=0xd63f0200;
        assert(!memcmp(image+0x7a94,&blraaz,4));memcpy(image+0x7a94,&blr,4);
    }
    assert(!mprotect(image,0x10000,PROT_READ|PROT_EXEC));
    __builtin___clear_cache((char *)image,(char *)image+allocated);
    puts("mapped Apple-call-intercepted loader; starting cases");fflush(stdout);
    void (*ctor)(void)=(void (*)(void))(image+(pac?0x7a3c:0x7604));
    void (*helper)(void)=(void (*)(void))(image+(pac?0x72bc:0x6f08));
    void (*callback)(void)=(void (*)(void))(image+(pac?0x76ec:0x72e0));
    int cases=0;
    for(int repeat=0;repeat<32;repeat++)for(enabled=0;enabled<2;enabled++)for(high=0;high<2;high++)for(found=0;found<2;found++)for(success=0;success<2;success++) {
        memset(calls,0,sizeof(calls));image[0x10494]=2;image[0x10497]=2;
        ctor();
        assert(calls[0]==1 && calls[3]==1);
        assert(calls[1]==(enabled&&high));assert(calls[2]==(enabled&&high&&found));
        assert(image[0x10494]==enabled && image[0x10497]==high);
        int before[4];memcpy(before,calls,sizeof(calls));helper();callback();assert(!memcmp(before,calls,sizeof(calls)));
        cases++;
    }
    printf("PASS %s: %d native AArch64 mocked cases; flags/dlsym/dlopen/pool/legacy no-ops. Auth=%s\n",pac?"arm64e":"arm64",cases,normalize_auth?"NORMALIZED; PAC NOT RUNTIME TESTED":(pac?"native":"not applicable"));
    assert(!munmap(image,allocated));return 0;
}
