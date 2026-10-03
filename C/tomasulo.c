#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
 
typedef uint32_t u32;
typedef int32_t  s32;
typedef uint8_t  u8;
 
#define NUM_FU       4          /* functional units == RS entries == CDB lanes */
#define ISSUE_WIDTH  4          /* instructions fetched/issued per cycle       */
#define NUM_REGS     32
#define IMEM_WORDS   256
#define RESET_PC     0u
#define NOP_INST     0x00000013u /* addi x0,x0,0 */
 
/* ======================================================================= */
/* 1. rv32i_types  (definitions / package)                                 */
/* ======================================================================= */
enum { OPC_R = 0x33, OPC_I_ALU = 0x13, OPC_I_LOAD = 0x03, OPC_I_JALR = 0x67,
       OPC_S = 0x23, OPC_B = 0x63, OPC_LUI = 0x37, OPC_AUIPC = 0x17,
       OPC_J = 0x6F };
 
typedef enum {
    TAG_NONE = 0,
    TAG_ALU1, TAG_ALU2, TAG_ALU3, TAG_ALU4,            /* used            */
    TAG_MUL1, TAG_MUL2, TAG_LOAD1, TAG_LOAD2,          /* reserved        */
    TAG_STORE1, TAG_STORE2
} RSTag;
 
typedef enum {
    ALU_ADD = 0, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU,
    ALU_XOR, ALU_SRL, ALU_SRA, ALU_OR, ALU_AND, ALU_NOP = 15
} alu_op_t;
 
typedef struct {
    int   valid, supported;
    u32   pc;
    u32   opcode, rd, rs1, rs2, funct3, funct7;
    u32   imm;
    alu_op_t op_name;
} DecodedInst;
 
static u32 sign_extend(u32 value, int from_bits)
{
    u32 m = 1u << (from_bits - 1);
    value &= (from_bits == 32) ? 0xFFFFFFFFu : ((1u << from_bits) - 1u);
    return (value ^ m) - m;
}
 
/* ======================================================================= */
/* 2. Instruction memory (external, combinational read)                    */
/* ======================================================================= */
typedef struct { u32 word[IMEM_WORDS]; u32 size; } InstMem;
 
static u32 imem_read(const InstMem *m, u32 addr)
{
    u32 i = addr >> 2;
    return (i < m->size) ? m->word[i] : NOP_INST;
}
 
/* ======================================================================= */
/* 3. frontend  (PC + fetch + decode, 4 wide)                              */
/* ======================================================================= */
typedef struct { u32 pc; } Frontend;
 
static DecodedInst decode(u32 pc, u32 inst)
{
    DecodedInst d; memset(&d, 0, sizeof d);
    d.valid  = 1;
    d.pc     = pc;
    d.opcode = inst & 0x7F;
    d.rd     = (inst >> 7)  & 0x1F;
    d.funct3 = (inst >> 12) & 0x7;
    d.rs1    = (inst >> 15) & 0x1F;
    d.rs2    = (inst >> 20) & 0x1F;
    d.funct7 = (inst >> 25) & 0x7F;
    d.op_name = ALU_NOP;
 
    int f7b5 = (d.funct7 >> 5) & 1;
    switch (d.opcode) {
    case OPC_R:
        d.supported = 1;
        switch (d.funct3) {
        case 0: d.op_name = f7b5 ? ALU_SUB : ALU_ADD; break;
        case 1: d.op_name = ALU_SLL;  break;
        case 2: d.op_name = ALU_SLT;  break;
        case 3: d.op_name = ALU_SLTU; break;
        case 4: d.op_name = ALU_XOR;  break;
        case 5: d.op_name = f7b5 ? ALU_SRA : ALU_SRL; break;
        case 6: d.op_name = ALU_OR;   break;
        default:d.op_name = ALU_AND;  break;
        }
        break;
    case OPC_I_ALU:
        d.supported = 1;
        d.imm = sign_extend(inst >> 20, 12);
        switch (d.funct3) {
        case 0: d.op_name = ALU_ADD;  break;       /* ADDI never SUB */
        case 1: d.op_name = ALU_SLL;  d.imm = d.rs2; break;
        case 2: d.op_name = ALU_SLT;  break;
        case 3: d.op_name = ALU_SLTU; break;
        case 4: d.op_name = ALU_XOR;  break;
        case 5: d.op_name = f7b5 ? ALU_SRA : ALU_SRL; d.imm = d.rs2; break;
        case 6: d.op_name = ALU_OR;   break;
        default:d.op_name = ALU_AND;  break;
        }
        break;
    case OPC_LUI:
    case OPC_AUIPC:
        d.supported = 1;
        d.imm = inst & 0xFFFFF000u;
        d.op_name = ALU_ADD;
        break;
    case OPC_I_LOAD: case OPC_I_JALR: case OPC_S: case OPC_B: case OPC_J:
    default:
        d.supported = 0;           /* decoded only, treated as bubble */
        break;
    }
    return d;
}
 
static void frontend_fetch(const Frontend *fe, const InstMem *im,
                           DecodedInst out[ISSUE_WIDTH])
{
    for (int k = 0; k < ISSUE_WIDTH; k++) {
        u32 pc = fe->pc + 4u * k;
        out[k] = decode(pc, imem_read(im, pc));
    }
}
 
static void frontend_clock(Frontend *fe, int reset, int stall)
{
    if (reset)       fe->pc = RESET_PC;
    else if (!stall) fe->pc += 4u * ISSUE_WIDTH;
}
 
/* ======================================================================= */
/* 4. rat  (Register Alias Table)                                          */
/* ======================================================================= */
typedef struct { RSTag tag[NUM_REGS]; } RAT;
 
static RSTag rat_lookup(const RAT *r, u32 reg) { return reg ? r->tag[reg] : TAG_NONE; }
 
static int rat_cdb_match(const RAT *r, int cdb_valid, RSTag cdb_tag)
{
    if (!cdb_valid) return 0;
    for (int i = 1; i < NUM_REGS; i++)
        if (r->tag[i] == cdb_tag) return 1;
    return 0;
}
 
/* ======================================================================= */
/* 5. arf  (Architectural Register File)                                   */
/* ======================================================================= */
typedef struct { u32 reg[NUM_REGS]; } ARF;
 
static u32 arf_read(const ARF *a, u32 r) { return r ? a->reg[r] : 0; }
 
/* ======================================================================= */
/* 6. reservation_station                                                  */
/* ======================================================================= */
typedef struct {
    int busy; alu_op_t op;
    u32 Vj, Vk; RSTag Qj, Qk;
    u32 dest;
} RSEntry;
 
typedef struct { RSEntry e[NUM_FU]; } RS;
 
static int rs_ready(const RSEntry *e)
{
    return e->busy && e->Qj == TAG_NONE && e->Qk == TAG_NONE && e->op != ALU_NOP;
}
 
/* ======================================================================= */
/* 7. functional_unit  (ALU_i, combinational, tag fixed = FU_TAG)          */
/* ======================================================================= */
typedef struct { int valid; RSTag tag; u32 data; u32 dest; } FUOut;
 
static u32 alu(alu_op_t op, u32 a, u32 b)
{
    u32 sh = b & 31;
    switch (op) {
    case ALU_ADD:  return a + b;
    case ALU_SUB:  return a - b;
    case ALU_SLL:  return a << sh;
    case ALU_SLT:  return (s32)a < (s32)b;
    case ALU_SLTU: return a < b;
    case ALU_XOR:  return a ^ b;
    case ALU_SRL:  return a >> sh;
    case ALU_SRA:  return (u32)((s32)a >> sh);
    case ALU_OR:   return a | b;
    case ALU_AND:  return a & b;
    default:       return 0;
    }
}
 
static FUOut functional_unit(RSTag fu_tag, const RSEntry *e)
{
    FUOut o;
    o.valid = rs_ready(e);
    o.tag   = fu_tag;
    o.data  = o.valid ? alu(e->op, e->Vj, e->Vk) : 0;
    o.dest  = e->dest;
    return o;
}
 
/* ======================================================================= */
/* 8. cdb  (Common Data Bus)                                               */
/*    4 FUs -> 4 lanes broadcast simultaneously; arbitration not needed.   */
/* ======================================================================= */
typedef struct { FUOut lane[NUM_FU]; } CDB;
 
/* ======================================================================= */
/* 9. tomasulo_core  (issue logic, combinational)                          */
/* ======================================================================= */
typedef struct {
    int en; RSTag tag;                       /* alloc_en, target entry tag */
    alu_op_t op; u32 Vj, Vk; RSTag Qj, Qk; u32 dest;
} AllocInfo;
 
typedef struct {
    AllocInfo alloc[ISSUE_WIDTH];            /* rs_alloc_info (+ rat_update) */
    int       stall_frontend;
} CoreOut;
 
static int cdb_hit(const CDB *c, RSTag tag, u32 *data)
{
    for (int i = 0; i < NUM_FU; i++)
        if (c->lane[i].valid && c->lane[i].tag == tag) { *data = c->lane[i].data; return 1; }
    return 0;
}
 
static int rs_entry_free_now(const RS *rs, const CDB *cdb, int i)
{
    /* free if idle, or if its result is broadcast this very cycle (release
       happens at the edge before allocation) */
    return !rs->e[i].busy || cdb->lane[i].valid;
}
 
static CoreOut tomasulo_core(const DecodedInst d[ISSUE_WIDTH], const RAT *rat,
                             const ARF *arf, const RS *rs, const CDB *cdb)
{
    CoreOut o; memset(&o, 0, sizeof o);
 
    /* rs_read_data: list of free entries, lowest first */
    RSTag free_tag[NUM_FU]; int nfree = 0;
    for (int i = 0; i < NUM_FU; i++)
        if (rs_entry_free_now(rs, cdb, i)) free_tag[nfree++] = (RSTag)(TAG_ALU1 + i);
 
    int need = 0, issuable[ISSUE_WIDTH];
    for (int k = 0; k < ISSUE_WIDTH; k++) {
        issuable[k] = d[k].valid && d[k].supported && d[k].rd != 0;
        need += issuable[k];
    }
    if (need > nfree) { o.stall_frontend = 1; return o; }   /* all-or-nothing */
 
    RSTag new_tag[NUM_REGS]; int renamed[NUM_REGS];
    memset(renamed, 0, sizeof renamed);
    int next_free = 0;
 
    for (int k = 0; k < ISSUE_WIDTH; k++) {
        if (!issuable[k]) continue;                         /* bubble */
        const DecodedInst *in = &d[k];
        AllocInfo *a = &o.alloc[k];
 
        /* resolve(): operand fetch with in-bundle rename + CDB bypass */
        #define RESOLVE(reg, V, Q) do {                                         \
            if ((reg) == 0)             { (V) = 0; (Q) = TAG_NONE; }            \
            else if (renamed[reg])      { (V) = 0; (Q) = new_tag[reg]; }        \
            else {                                                              \
                RSTag t = rat_lookup(rat, (reg)); u32 cd;                       \
                if (t == TAG_NONE)           { (V) = arf_read(arf, (reg)); (Q) = TAG_NONE; } \
                else if (cdb_hit(cdb, t, &cd)) { (V) = cd; (Q) = TAG_NONE; }   \
                else                         { (V) = 0; (Q) = t; }              \
            } } while (0)
 
        if (in->opcode == OPC_LUI)        { a->Vj = 0;     a->Qj = TAG_NONE; }
        else if (in->opcode == OPC_AUIPC) { a->Vj = in->pc; a->Qj = TAG_NONE; }
        else                              RESOLVE(in->rs1, a->Vj, a->Qj);
 
        if (in->opcode == OPC_R)          RESOLVE(in->rs2, a->Vk, a->Qk);
        else                              { a->Vk = in->imm; a->Qk = TAG_NONE; }
        #undef RESOLVE
 
        a->en   = 1;
        a->tag  = free_tag[next_free++];
        a->op   = in->op_name;
        a->dest = in->rd;
 
        renamed[in->rd] = 1;                 /* rat_update for later slots */
        new_tag[in->rd] = a->tag;
    }
    return o;
}
 
/* ======================================================================= */
/* 10. top : structural netlist + clock edge                               */
/* ======================================================================= */
typedef struct {
    Frontend fe; RAT rat; ARF arf; RS rs;
    InstMem  im;
    unsigned long cycles, issued, retired;
} Machine;
 
static void machine_reset(Machine *m)
{
    u32 keep_size = m->im.size;
    memset(&m->rat, 0, sizeof m->rat);      /* all NONE   */
    memset(&m->rs , 0, sizeof m->rs );      /* all free   */
    frontend_clock(&m->fe, 1, 0);           /* PC = RESET */
    m->im.size = keep_size;
    m->cycles = m->issued = m->retired = 0;
}
 
static int machine_busy(const Machine *m)
{
    for (int i = 0; i < NUM_FU; i++) if (m->rs.e[i].busy) return 1;
    return 0;
}
 
static void machine_cycle(Machine *m, int verbose)
{
    /* ---- combinational phase ---- */
    DecodedInst d[ISSUE_WIDTH];
    frontend_fetch(&m->fe, &m->im, d);
 
    CDB cdb;
    for (int i = 0; i < NUM_FU; i++)
        cdb.lane[i] = functional_unit((RSTag)(TAG_ALU1 + i), &m->rs.e[i]);
 
    CoreOut co = tomasulo_core(d, &m->rat, &m->arf, &m->rs, &cdb);
 
    int match[NUM_FU];                       /* from pre-edge RAT */
    for (int i = 0; i < NUM_FU; i++)
        match[i] = rat_cdb_match(&m->rat, cdb.lane[i].valid, cdb.lane[i].tag);
 
    if (verbose) {
        printf("cycle %2lu | pc=%3u | EXEC:", m->cycles, m->fe.pc);
        for (int i = 0; i < NUM_FU; i++) {
            if (cdb.lane[i].valid)
                printf(" ALU%d[x%u=0x%08x]", i + 1, cdb.lane[i].dest, cdb.lane[i].data);
            else printf(" ALU%d[ idle         ]", i + 1);
        }
        int n = 0; for (int k = 0; k < ISSUE_WIDTH; k++) n += co.alloc[k].en;
        printf(" | ISSUE:%d%s\n", n, co.stall_frontend ? " STALL" : "");
    }
 
    /* ---- clock edge ---- */
    /* ARF: commit only if still newest producer (WAW protection) */
    for (int i = 0; i < NUM_FU; i++) {
        if (cdb.lane[i].valid) m->retired++;
        if (match[i] && cdb.lane[i].dest != 0)
            m->arf.reg[cdb.lane[i].dest] = cdb.lane[i].data;
    }
 
    /* RAT: clear by broadcast tag, then rename (rename wins) */
    for (int i = 0; i < NUM_FU; i++)
        if (cdb.lane[i].valid)
            for (int r = 1; r < NUM_REGS; r++)
                if (m->rat.tag[r] == cdb.lane[i].tag) m->rat.tag[r] = TAG_NONE;
    for (int k = 0; k < ISSUE_WIDTH; k++)
        if (co.alloc[k].en) m->rat.tag[co.alloc[k].dest] = co.alloc[k].tag;
 
    /* RS: wake-up + release of existing entries, then allocation */
    for (int i = 0; i < NUM_FU; i++) {
        RSEntry *e = &m->rs.e[i];
        if (!e->busy) continue;
        if (cdb.lane[i].valid) { e->busy = 0; continue; }   /* release */
        for (int l = 0; l < NUM_FU; l++) {
            if (!cdb.lane[l].valid) continue;
            if (e->Qj == cdb.lane[l].tag) { e->Vj = cdb.lane[l].data; e->Qj = TAG_NONE; }
            if (e->Qk == cdb.lane[l].tag) { e->Vk = cdb.lane[l].data; e->Qk = TAG_NONE; }
        }
    }
    for (int k = 0; k < ISSUE_WIDTH; k++) {
        const AllocInfo *a = &co.alloc[k];
        if (!a->en) continue;
        RSEntry *e = &m->rs.e[a->tag - TAG_ALU1];
        e->busy = 1; e->op = a->op; e->Vj = a->Vj; e->Vk = a->Vk;
        e->Qj = a->Qj; e->Qk = a->Qk; e->dest = a->dest;
        m->issued++;
    }
 
    frontend_clock(&m->fe, 0, co.stall_frontend);
    m->cycles++;
}
 
/* ======================================================================= */
/* Test bench: tiny assembler, programs, golden model                      */
/* ======================================================================= */
#define ENC_R(f7,rs2,rs1,f3,rd,op) (((u32)(f7)<<25)|((u32)(rs2)<<20)|((u32)(rs1)<<15)|((u32)(f3)<<12)|((u32)(rd)<<7)|(op))
#define ENC_I(imm,rs1,f3,rd,op)    ((((u32)(imm)&0xFFF)<<20)|((u32)(rs1)<<15)|((u32)(f3)<<12)|((u32)(rd)<<7)|(op))
#define ENC_U(imm20,rd,op)         (((u32)(imm20)<<12)|((u32)(rd)<<7)|(op))
 
#define ADD(rd,a,b)   ENC_R(0x00,b,a,0,rd,OPC_R)
#define SUB(rd,a,b)   ENC_R(0x20,b,a,0,rd,OPC_R)
#define SLL(rd,a,b)   ENC_R(0x00,b,a,1,rd,OPC_R)
#define SLT(rd,a,b)   ENC_R(0x00,b,a,2,rd,OPC_R)
#define SLTU(rd,a,b)  ENC_R(0x00,b,a,3,rd,OPC_R)
#define XOR(rd,a,b)   ENC_R(0x00,b,a,4,rd,OPC_R)
#define SRL(rd,a,b)   ENC_R(0x00,b,a,5,rd,OPC_R)
#define SRA(rd,a,b)   ENC_R(0x20,b,a,5,rd,OPC_R)
#define OR(rd,a,b)    ENC_R(0x00,b,a,6,rd,OPC_R)
#define AND(rd,a,b)   ENC_R(0x00,b,a,7,rd,OPC_R)
#define ADDI(rd,a,i)  ENC_I(i,a,0,rd,OPC_I_ALU)
#define SLTI(rd,a,i)  ENC_I(i,a,2,rd,OPC_I_ALU)
#define SLTIU(rd,a,i) ENC_I(i,a,3,rd,OPC_I_ALU)
#define XORI(rd,a,i)  ENC_I(i,a,4,rd,OPC_I_ALU)
#define ORI(rd,a,i)   ENC_I(i,a,6,rd,OPC_I_ALU)
#define ANDI(rd,a,i)  ENC_I(i,a,7,rd,OPC_I_ALU)
#define SLLI(rd,a,s)  ENC_I(s,a,1,rd,OPC_I_ALU)
#define SRLI(rd,a,s)  ENC_I(s,a,5,rd,OPC_I_ALU)
#define SRAI(rd,a,s)  ENC_I(0x400|(s),a,5,rd,OPC_I_ALU)
#define LUI(rd,i20)   ENC_U(i20,rd,OPC_LUI)
#define AUIPC(rd,i20) ENC_U(i20,rd,OPC_AUIPC)
 
/* 24 instructions = 6 bundles of 4.  Sources only x0..x7 (preloaded, never
   written); destinations x8..x31 all distinct -> no RAW, WAW or WAR. */
static const u32 PROG_INDEP[] = {
    /* bundle 0 */ ADD(8,1,2),   SUB(9,3,4),    XOR(10,5,6),  AND(11,7,1),
    /* bundle 1 */ OR(12,2,3),   SLL(13,4,5),   SRL(14,6,7),  SRA(15,1,4),
    /* bundle 2 */ SLT(16,2,5),  SLTU(17,3,6),  ADD(18,7,7),  SUB(19,1,7),
    /* bundle 3 */ ADDI(20,1,100), SLTI(21,2,-5), SLTIU(22,3,50), XORI(23,4,0x55),
    /* bundle 4 */ ORI(24,5,0x0F0), ANDI(25,6,0x3C), SLLI(26,7,3), SRLI(27,1,2),
    /* bundle 5 */ SRAI(28,4,1), LUI(29,0x12345), AUIPC(30,1), ADDI(31,0,-1)
};
 
/* Dependent program (RAW inside bundle, across bundles, WAW) */
static const u32 PROG_DEP[] = {
    ADD(3,1,2),   SUB(4,3,1),   AND(5,2,2),   ADDI(6,4,5),   /* intra-bundle RAW */
    ADD(5,5,6),   ADD(5,1,1),   SLLI(7,5,2),  XOR(3,3,5),    /* WAW on x5        */
    ADD(8,3,4),   ADD(9,8,7),   SUB(10,9,8),  ADD(11,10,10), /* RAW chain        */
    ADDI(12,0,7), ADDI(0,1,1),  ADD(13,12,12),SLT(14,13,12)  /* x0 dest = bubble */
};
 
static void preload(ARF *a)
{
    static const u32 init[8] = {0, 0x11, 0x2222, 0x00FF00FF, 0xFFFFFFF0u,
                                0x7FFFFFFF, 0x80000001u, 7};
    memset(a, 0, sizeof *a);
    for (int i = 0; i < 8; i++) a->reg[i] = init[i];
    a->reg[0] = 0;
}
 
static void golden(const InstMem *im, ARF *a)
{
    for (u32 i = 0; i < im->size; i++) {
        DecodedInst d = decode(i * 4, im->word[i]);
        if (!d.supported || d.rd == 0) continue;
        u32 x = (d.opcode == OPC_LUI) ? 0 : (d.opcode == OPC_AUIPC) ? d.pc
                                                                     : a->reg[d.rs1];
        u32 y = (d.opcode == OPC_R) ? a->reg[d.rs2] : d.imm;
        a->reg[d.rd] = alu(d.op_name, x, y);
    }
}
 
int main(int argc, char **argv)
{
    int dep = 0, verbose = 1;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-d")) dep = 1;
        if (!strcmp(argv[i], "-q")) verbose = 0;
    }
    const u32 *prog = dep ? PROG_DEP : PROG_INDEP;
    u32 n = dep ? sizeof PROG_DEP / 4 : sizeof PROG_INDEP / 4;
 
    static Machine m;
    memset(&m, 0, sizeof m);
    memcpy(m.im.word, prog, n * 4);
    m.im.size = n;
    machine_reset(&m);
    preload(&m.arf);                          /* backdoor preload, like $readmemh */
 
    printf("== Tomasulo engine: %d FUs, %d-wide issue, %d CDB lanes, %s program (%u insts) ==\n",
           NUM_FU, ISSUE_WIDTH, NUM_FU, dep ? "DEPENDENT" : "INDEPENDENT", n);
 
    while ((m.fe.pc < n * 4u || machine_busy(&m)) && m.cycles < 1000)
        machine_cycle(&m, verbose);
 
    ARF ref; preload(&ref); golden(&m.im, &ref);
    int bad = 0;
    for (int r = 0; r < NUM_REGS; r++)
        if (ref.reg[r] != m.arf.reg[r]) {
            printf("MISMATCH x%d: got 0x%08x expected 0x%08x\n", r, m.arf.reg[r], ref.reg[r]);
            bad++;
        }
    for (int r = 1; r < NUM_REGS; r++)
        if (m.rat.tag[r] != TAG_NONE) { printf("RAT x%d not cleared\n", r); bad++; }
 
    unsigned long issue_cycles = (n + ISSUE_WIDTH - 1) / ISSUE_WIDTH;
    printf("\ninstructions issued : %lu\ninstructions retired: %lu\ntotal cycles        : %lu"
           "  (%lu issue cycles + 1 drain)\n",
           m.issued, m.retired, m.cycles, issue_cycles);
    printf("steady-state rate   : %d issued and %d executed per cycle\n", ISSUE_WIDTH, NUM_FU);
    printf("result vs golden    : %s\n", bad ? "FAIL" : "PASS (ARF identical, RAT clean)");
    return bad != 0;
}
 