// ITCH 5.0 types shared by the RTL.  Mirrors struct parsed in model/itch.hpp field for field,
// so the testbench scoreboard can compare by name.  Keep the two in sync.
//
// Packed struct: the first field listed occupies the most significant bits.
package itch_pkg;

    typedef enum logic [0:0] { CLEAN = 1'b0, BAD = 1'b1 } parsestatus_t;

    typedef struct packed {
        logic [63:0] order_ref;
        logic [7:0]  side;
        logic [31:0] shares;
        logic [63:0] stock;
        logic [31:0] price;
        logic [31:0] exshare;
        logic [63:0] mnum;
        logic [31:0] execprice;
        logic [7:0]  printable;
        logic [31:0] atr;
        logic [7:0]  tradestate;
        logic [7:0]  reserved;
        logic [31:0] reason_code;
        logic [7:0]  market_code;
        logic [7:0]  halt;
        logic [63:0] parshar;
        logic [63:0] imb_shares;
        logic [7:0]  imb_dir;
        logic [31:0] far_prc;
        logic [31:0] near_prc;
        logic [31:0] cref;
        logic [7:0]  crstype;
        logic [7:0]  pricevar;
        logic [31:0] rprc;
        logic [31:0] ucllr;
        logic [31:0] lcllr;
        logic [31:0] ex;
        logic [31:0] reltime;
        logic [7:0]  relqual;
        logic [31:0] ipoprc;
        logic [31:0] MPID;
        logic [7:0]  pmm;
        logic [7:0]  mmmm;
        logic [7:0]  mps;
        logic [7:0]  intflg;
        logic [7:0]  opnelg;
        logic [31:0] minprc;
        logic [31:0] maxprc;
        logic [31:0] nearexp;
        logic [63:0] nearext;
        logic [31:0] crsprc;
        logic [63:0] lshare;
        logic [7:0]  evntcd;
        logic [63:0] ogref;
        logic [63:0] nwref;
        logic [63:0] level1;
        logic [63:0] level2;
        logic [63:0] level3;
        logic [7:0]  breachedlvl;
        logic [31:0] xshare;
        logic [7:0]  regsho;
        logic [7:0]  markcat;
        logic [7:0]  finstat;
        logic [31:0] rndltsz;
        logic [7:0]  rndltsnly;
        logic [15:0] isssubtyp;
        logic [7:0]  issueclar;
        logic [7:0]  auth;
        logic [7:0]  shortsalethres;
        logic [7:0]  ipoflg;
        logic [7:0]  LULD;
        logic [7:0]  ETPF;
        logic [31:0] ETPLF;
        logic [7:0]  invind;
        logic [7:0]  msg_type;          // C++: type (a reserved word in SystemVerilog)
        logic [15:0] location;
        logic [15:0] tracking_number;
        logic [47:0] time_ns;           // C++: time (reserved in SystemVerilog)
        parsestatus_t pstat;
    } parsed_t;

endpackage
