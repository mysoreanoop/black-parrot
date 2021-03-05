/**
  *
  * testbench.v
  *
  */

`include "bsg_noc_links.vh"

module testbench
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR // Replaced by the flow with a specific bp_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

   // TRACE enable parameters
   , parameter icache_trace_p              = 0
   , parameter dcache_trace_p              = 0
   , parameter lce_trace_p                 = 0
   , parameter cce_trace_p                 = 0
   , parameter dram_trace_p                = 0
   , parameter vm_trace_p                  = 0
   , parameter cmt_trace_p                 = 0
   , parameter core_profile_p              = 0
   , parameter pc_profile_p                = 0
   , parameter br_profile_p                = 0
   , parameter cosim_p                     = 0

   // COSIM parameters
   , parameter checkpoint_p                = 0
   , parameter cosim_memsize_p             = 0
   , parameter cosim_cfg_file_p            = "prog.cfg"
   , parameter cosim_instr_p               = 0
   , parameter warmup_instr_p              = 0
   , parameter amo_en_p                    = 0

   // DRAM parameters
   , parameter dram_type_p                 = BP_DRAM_FLOWVAR // Replaced by the flow with a specific dram_type
   , parameter [paddr_width_p-1:0] mem_offset_p = dram_base_addr_gp
   , parameter mem_cap_in_bytes_p = 2**27
   , parameter mem_file_p         = "prog.mem"

   // Synthesis parameters
   , parameter no_bind_p                   = 0

   )
  (input clk_i
   , input reset_i
   , input dram_clk_i
   , input dram_reset_i
   );

  import "DPI-C" context function bit get_finish(int hartid);
  export "DPI-C" function get_dram_period;
  export "DPI-C" function get_sim_period;

  function int get_dram_period();
    return (`dram_pkg::tck_ps);
  endfunction

  function int get_sim_period();
    return (`BP_SIM_CLK_PERIOD);
  endfunction

  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);

  bp_bedrock_cce_mem_msg_s proc_io_cmd_lo;
  logic proc_io_cmd_v_lo, proc_io_cmd_ready_li;
  bp_bedrock_cce_mem_msg_s proc_io_resp_li;
  logic proc_io_resp_v_li, proc_io_resp_yumi_lo;

  bp_bedrock_cce_mem_msg_s io_cmd_lo;
  logic io_cmd_v_lo, io_cmd_ready_li;
  bp_bedrock_cce_mem_msg_s io_resp_li;
  logic io_resp_v_li, io_resp_yumi_lo;

  bp_bedrock_cce_mem_msg_s load_cmd_lo;
  logic load_cmd_v_lo, load_cmd_yumi_li;
  bp_bedrock_cce_mem_msg_s load_resp_li;
  logic load_resp_v_li, load_resp_ready_lo;

  `declare_bsg_cache_dma_pkt_s(caddr_width_p);
  bsg_cache_dma_pkt_s [cc_x_dim_p-1:0] dma_pkt_lo;
  logic [cc_x_dim_p-1:0] dma_pkt_v_lo, dma_pkt_yumi_li;
  logic [cc_x_dim_p-1:0][mem_noc_flit_width_p-1:0] dma_data_lo;
  logic [cc_x_dim_p-1:0] dma_data_v_lo, dma_data_yumi_li;
  logic [cc_x_dim_p-1:0][mem_noc_flit_width_p-1:0] dma_data_li;
  logic [cc_x_dim_p-1:0] dma_data_v_li, dma_data_ready_lo;
  wrapper
   #(.bp_params_p(bp_params_p))
   wrapper
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.io_cmd_o(proc_io_cmd_lo)
     ,.io_cmd_v_o(proc_io_cmd_v_lo)
     ,.io_cmd_ready_i(proc_io_cmd_ready_li)

     ,.io_resp_i(proc_io_resp_li)
     ,.io_resp_v_i(proc_io_resp_v_li)
     ,.io_resp_yumi_o(proc_io_resp_yumi_lo)

     ,.io_cmd_i(load_cmd_lo)
     ,.io_cmd_v_i(load_cmd_v_lo)
     ,.io_cmd_yumi_o(load_cmd_yumi_li)

     ,.io_resp_o(load_resp_li)
     ,.io_resp_v_o(load_resp_v_li)
     ,.io_resp_ready_i(load_resp_ready_lo)

     ,.dma_pkt_o(dma_pkt_lo)
     ,.dma_pkt_v_o(dma_pkt_v_lo)
     ,.dma_pkt_yumi_i(dma_pkt_yumi_li)

     ,.dma_data_i(dma_data_li)
     ,.dma_data_v_i(dma_data_v_li)
     ,.dma_data_ready_o(dma_data_ready_lo)

     ,.dma_data_o(dma_data_lo)
     ,.dma_data_v_o(dma_data_v_lo)
     ,.dma_data_yumi_i(dma_data_yumi_li)
     );

  `ifndef dram_pkg
  `define dram_pkg bsg_dramsim3_lpddr3_8gb_x32_1600_pkg
  `endif
  if (dram_type_p == "dmc")
    begin : dmc
      bp_ddr
       #(.bp_params_p(bp_params_p))
       ddr
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.dma_pkt_i(dma_pkt_lo)
         ,.dma_pkt_v_i(dma_pkt_v_lo)
         ,.dma_pkt_yumi_o(dma_pkt_yumi_li)

         ,.dma_data_o(dma_data_li)
         ,.dma_data_v_o(dma_data_v_li)
         ,.dma_data_ready_i(dma_data_ready_lo)

         ,.dma_data_i(dma_data_lo)
         ,.dma_data_v_i(dma_data_v_lo)
         ,.dma_data_yumi_o(dma_data_yumi_li)
         );
    end
  else if (dram_type_p == "dramsim3")
    begin : dramsim3
      for (genvar i = 0; i < cc_x_dim_p; i++)
        begin : channel
          `dram_pkg::dram_ch_addr_s dram_read_done_ch_addr_lo;

          logic [`dram_pkg::channel_addr_width_p-1:0] dram_ch_addr_li;
          logic dram_write_not_read_li, dram_v_li, dram_yumi_lo;
          logic [`dram_pkg::data_width_p-1:0] dram_data_li;
          logic dram_data_v_li, dram_data_yumi_lo;
          logic [`dram_pkg::data_width_p-1:0] dram_data_lo;
          logic dram_data_v_lo;

          localparam cache_block_size_in_words_lp = cce_block_width_p/dword_width_gp;
          localparam cache_bank_addr_width_lp = `BSG_SAFE_CLOG2(2**29/1*4);
          bsg_cache_to_test_dram
           #(.num_cache_p(1)
             ,.addr_width_p(caddr_width_p)
             ,.data_width_p(dword_width_gp)
             ,.block_size_in_words_p(cache_block_size_in_words_lp)
             ,.cache_bank_addr_width_p(cache_bank_addr_width_lp)
             ,.dma_data_width_p(mem_noc_flit_width_p)
          
             ,.dram_channel_addr_width_p(`dram_pkg::channel_addr_width_p)
             ,.dram_data_width_p(`dram_pkg::data_width_p)
             )
           cache_to_tram
           (.core_clk_i(clk_i)
            ,.core_reset_i(reset_i)

            ,.dma_pkt_i(dma_pkt_lo[i])
            ,.dma_pkt_v_i(dma_pkt_v_lo[i])
            ,.dma_pkt_yumi_o(dma_pkt_yumi_li[i])

            ,.dma_data_o(dma_data_li[i])
            ,.dma_data_v_o(dma_data_v_li[i])
            ,.dma_data_ready_i(dma_data_ready_lo[i])

            ,.dma_data_i(dma_data_lo[i])
            ,.dma_data_v_i(dma_data_v_lo[i])
            ,.dma_data_yumi_o(dma_data_yumi_li[i])

            ,.dram_clk_i(dram_clk_i)
            ,.dram_reset_i(dram_reset_i)
          
            ,.dram_req_v_o(dram_v_li)
            ,.dram_write_not_read_o(dram_write_not_read_li)
            ,.dram_ch_addr_o(dram_ch_addr_li)
            ,.dram_req_yumi_i(dram_yumi_lo)
            ,.dram_data_v_o(dram_data_v_li)
            ,.dram_data_o(dram_data_li)
            ,.dram_data_yumi_i(dram_data_yumi_lo)

            ,.dram_data_v_i(dram_data_v_lo)
            ,.dram_data_i(dram_data_lo)
            ,.dram_ch_addr_i(dram_read_done_ch_addr_lo)
            );

          bsg_nonsynth_dramsim3
           #(.channel_addr_width_p(`dram_pkg::channel_addr_width_p)
             ,.data_width_p(`dram_pkg::data_width_p)
             ,.num_channels_p(`dram_pkg::num_channels_p)
             ,.num_columns_p(`dram_pkg::num_columns_p)
             ,.num_rows_p(`dram_pkg::num_rows_p)
             ,.num_ba_p(`dram_pkg::num_ba_p)
             ,.num_bg_p(`dram_pkg::num_bg_p)
             ,.num_ranks_p(`dram_pkg::num_ranks_p)
             ,.address_mapping_p(`dram_pkg::address_mapping_p)
             ,.size_in_bits_p(`dram_pkg::size_in_bits_p)
             ,.config_p(`dram_pkg::config_p)
             ,.init_mem_p(1)
             ,.base_id_p(0)
             )
           dram
            (.clk_i(dram_clk_i)
             ,.reset_i(dram_reset_i)
              
             ,.v_i(dram_v_li)
             ,.write_not_read_i(dram_write_not_read_li)
             ,.ch_addr_i(dram_ch_addr_li)
             ,.mask_i('1)
             ,.yumi_o(dram_yumi_lo)

             ,.data_v_i(dram_data_v_li)
             ,.data_i(dram_data_li)
             ,.data_yumi_o(dram_data_yumi_lo)

             ,.data_v_o(dram_data_v_lo)
             ,.data_o(dram_data_lo)
             ,.read_done_ch_addr_o(dram_read_done_ch_addr_lo)

             ,.write_done_o()
             ,.write_done_ch_addr_o()
             );
        end
    end
  else if (dram_type_p == "axi")
    begin : axi
      localparam axi_id_width_p = 6;
      localparam axi_addr_width_p = 64;
      localparam axi_data_width_p = 512;
      localparam axi_strb_width_p = axi_data_width_p >> 3;
      localparam axi_burst_len_p = 1;

      logic [axi_id_width_p-1:0] axi_awid;
      logic [axi_addr_width_p-1:0] axi_awaddr;
      logic [7:0] axi_awlen;
      logic [2:0] axi_awsize;
      logic [1:0] axi_awburst;
      logic [3:0] axi_awcache;
      logic [2:0] axi_awprot;
      logic axi_awlock, axi_awvalid, axi_awready;

      logic [axi_data_width_p-1:0] axi_wdata;
      logic [axi_strb_width_p-1:0] axi_wstrb;
      logic axi_wlast, axi_wvalid, axi_wready;

      logic [axi_id_width_p-1:0] axi_bid;
      logic [1:0] axi_bresp;
      logic axi_bvalid, axi_bready;

      logic [axi_id_width_p-1:0] axi_arid;
      logic [axi_addr_width_p-1:0] axi_araddr;
      logic [7:0] axi_arlen;
      logic [2:0] axi_arsize;
      logic [1:0] axi_arburst;
      logic [3:0] axi_arcache;
      logic [2:0] axi_arprot;
      logic axi_arlock, axi_arvalid, axi_arready;

      logic [axi_id_width_p-1:0] axi_rid;
      logic [axi_data_width_p-1:0] axi_rdata;
      logic [1:0] axi_rresp;
      logic axi_rlast, axi_rvalid, axi_rready;

      bsg_cache_to_axi
       #(.addr_width_p(caddr_width_p)
         ,.block_size_in_words_p(cce_block_width_p/dword_width_gp)
         ,.data_width_p(dword_width_gp)
         ,.num_cache_p(cc_x_dim_p)
         ,.axi_id_width_p(axi_id_width_p)
         ,.axi_addr_width_p(axi_addr_width_p)
         ,.axi_data_width_p(axi_data_width_p)
         ,.axi_burst_len_p(axi_burst_len_p)
         )
      cache2axi
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.dma_pkt_i(dma_pkt_lo)
         ,.dma_pkt_v_i(dma_pkt_v_lo)
         ,.dma_pkt_yumi_o(dma_pkt_yumi_li)

         ,.dma_data_o(dma_data_li)
         ,.dma_data_v_o(dma_data_v_li)
         ,.dma_data_ready_i(dma_data_ready_lo)

         ,.dma_data_i(dma_data_lo)
         ,.dma_data_v_i(dma_data_v_lo)
         ,.dma_data_yumi_o(dma_data_yumi_li)

         ,.axi_awid_o(axi_awid)
         ,.axi_awaddr_o(axi_awaddr)
         ,.axi_awlen_o(axi_awlen)
         ,.axi_awsize_o(axi_awsize)
         ,.axi_awburst_o(axi_awburst)
         ,.axi_awcache_o(axi_awcache)
         ,.axi_awprot_o(axi_awprot)
         ,.axi_awlock_o(axi_awlock)
         ,.axi_awvalid_o(axi_awvalid)
         ,.axi_awready_i(axi_awready)

         ,.axi_wdata_o(axi_wdata)
         ,.axi_wstrb_o(axi_wstrb)
         ,.axi_wlast_o(axi_wlast)
         ,.axi_wvalid_o(axi_wvalid)
         ,.axi_wready_i(axi_wready)

         ,.axi_bid_i(axi_bid)
         ,.axi_bresp_i(axi_bresp)
         ,.axi_bvalid_i(axi_bvalid)
         ,.axi_bready_o(axi_bready)

         ,.axi_arid_o(axi_arid)
         ,.axi_araddr_o(axi_araddr)
         ,.axi_arlen_o(axi_arlen)
         ,.axi_arsize_o(axi_arsize)
         ,.axi_arburst_o(axi_arburst)
         ,.axi_arcache_o(axi_arcache)
         ,.axi_arprot_o(axi_arprot)
         ,.axi_arlock_o(axi_arlock)
         ,.axi_arvalid_o(axi_arvalid)
         ,.axi_arready_i(axi_arready)

         ,.axi_rid_i(axi_rid)
         ,.axi_rdata_i(axi_rdata)
         ,.axi_rresp_i(axi_rresp)
         ,.axi_rlast_i(axi_rlast)
         ,.axi_rvalid_i(axi_rvalid)
         ,.axi_rready_o(axi_rready)
         );

      bsg_nonsynth_axi_mem
       #(.axi_id_width_p(axi_id_width_p)
         ,.axi_addr_width_p(axi_addr_width_p)
         ,.axi_data_width_p(axi_data_width_p)
         ,.axi_burst_len_p(axi_burst_len_p)
         ,.mem_els_p(2**31/(axi_data_width_p>>3))
         )
       axi_mem
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.axi_awid_i(axi_awid)
         ,.axi_awaddr_i(axi_awaddr)
         ,.axi_awvalid_i(axi_awvalid)
         ,.axi_awready_o(axi_awready)

         ,.axi_wdata_i(axi_wdata)
         ,.axi_wstrb_i(axi_wstrb)
         ,.axi_wlast_i(axi_wlast)
         ,.axi_wvalid_i(axi_wvalid)
         ,.axi_wready_o(axi_wready)

         ,.axi_bid_o(axi_bid)
         ,.axi_bresp_o(axi_bresp)
         ,.axi_bvalid_o(axi_bvalid)
         ,.axi_bready_i(axi_bready)

         ,.axi_arid_i(axi_arid)
         ,.axi_araddr_i(axi_araddr)
         ,.axi_arvalid_i(axi_arvalid)
         ,.axi_arready_o(axi_arready)

         ,.axi_rid_o(axi_rid)
         ,.axi_rdata_o(axi_rdata)
         ,.axi_rresp_o(axi_rresp)
         ,.axi_rlast_o(axi_rlast)
         ,.axi_rvalid_o(axi_rvalid)
         ,.axi_rready_i(axi_rready)
         );
    end
  else
    begin : no_mem
      $error("Must select dram_type as either dramsim3, dmc, or axi");
    end

  bp_nonsynth_nbf_loader
   #(.bp_params_p(bp_params_p))
   nbf_loader
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.lce_id_i(lce_id_width_p'('b10))

     ,.io_cmd_o(load_cmd_lo)
     ,.io_cmd_v_o(load_cmd_v_lo)
     ,.io_cmd_yumi_i(load_cmd_yumi_li)

     ,.io_resp_i(load_resp_li)
     ,.io_resp_v_i(load_resp_v_li)
     ,.io_resp_ready_o(load_resp_ready_lo)

     ,.done_o()
     );

  logic cosim_en_lo;
  logic icache_trace_en_lo;
  logic dcache_trace_en_lo;
  logic lce_trace_en_lo;
  logic cce_trace_en_lo;
  logic dram_trace_en_lo;
  logic vm_trace_en_lo;
  logic cmt_trace_en_lo;
  logic core_profile_en_lo;
  logic pc_profile_en_lo;
  logic branch_profile_en_lo;
  bp_nonsynth_host
   #(.bp_params_p(bp_params_p)
     ,.icache_trace_p(icache_trace_p)
     ,.dcache_trace_p(dcache_trace_p)
     ,.lce_trace_p(lce_trace_p)
     ,.cce_trace_p(cce_trace_p)
     ,.dram_trace_p(dram_trace_p)
     ,.vm_trace_p(vm_trace_p)
     ,.cmt_trace_p(cmt_trace_p)
     ,.core_profile_p(core_profile_p)
     ,.pc_profile_p(pc_profile_p)
     ,.br_profile_p(br_profile_p)
     ,.cosim_p(cosim_p)
     )
   host
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.io_cmd_i(proc_io_cmd_lo)
     ,.io_cmd_v_i(proc_io_cmd_v_lo & proc_io_cmd_ready_li)
     ,.io_cmd_ready_o(proc_io_cmd_ready_li)

     ,.io_resp_o(proc_io_resp_li)
     ,.io_resp_v_o(proc_io_resp_v_li)
     ,.io_resp_yumi_i(proc_io_resp_yumi_lo)

     ,.icache_trace_en_o(icache_trace_en_lo)
     ,.dcache_trace_en_o(dcache_trace_en_lo)
     ,.lce_trace_en_o(lce_trace_en_lo)
     ,.cce_trace_en_o(cce_trace_en_lo)
     ,.dram_trace_en_o(dram_trace_en_lo)
     ,.vm_trace_en_o(vm_trace_en_lo)
     ,.cmt_trace_en_o(cmt_trace_en_lo)
     ,.core_profile_en_o(core_profile_en_lo)
     ,.branch_profile_en_o(branch_profile_en_lo)
     ,.pc_profile_en_o(pc_profile_en_lo)
     ,.cosim_en_o(cosim_en_lo)
     );

  if (no_bind_p == 0)
    begin : do_bind
      bind bp_be_top
        bp_nonsynth_perf
         #(.bp_params_p(bp_params_p))
         perf
          (.clk_i(clk_i)
           ,.reset_i(reset_i)
           ,.freeze_i(calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)
           ,.warmup_instr_i(testbench.warmup_instr_p)

           ,.mhartid_i(calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)

           ,.commit_v_i(calculator.commit_pkt_cast_o.instret)
           ,.is_debug_mode_i(calculator.pipe_sys.csr.is_debug_mode)
           );

      bind bp_be_top
        bp_nonsynth_watchdog
         #(.bp_params_p(bp_params_p)
           ,.timeout_cycles_p(100000)
           ,.heartbeat_instr_p(100000)
           )
         watchdog
          (.clk_i(clk_i)
           ,.reset_i(reset_i)
           ,.freeze_i(calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)
           ,.wfi_i(director.is_wait)

           ,.mhartid_i(calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)

           ,.npc_i(calculator.pipe_sys.csr.apc_r)
           ,.instret_i(calculator.commit_pkt_cast_o.instret)
           );


      bind bp_be_top
        bp_nonsynth_cosim
         #(.bp_params_p(bp_params_p))
         cosim
          (.clk_i(clk_i)
           ,.reset_i(reset_i)
           ,.freeze_i(calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)

           // We want to pass these values as parameters, but cannot in Verilator 4.025
           // Parameter-resolved constants must not use dotted references
           ,.cosim_en_i(testbench.cosim_en_lo)
           ,.trace_en_i(testbench.cmt_trace_en_lo)
           ,.checkpoint_i(testbench.checkpoint_p == 1)
           ,.num_core_i(testbench.num_core_p)
           ,.mhartid_i(calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)
           ,.config_file_i(testbench.cosim_cfg_file_p)
           ,.instr_cap_i(testbench.cosim_instr_p)
           ,.memsize_i(testbench.cosim_memsize_p)
           ,.amo_en_i(testbench.amo_en_p == 1)

           ,.decode_i(calculator.reservation_n.decode)

           ,.is_debug_mode_i(calculator.pipe_sys.csr.is_debug_mode)
           ,.commit_pkt_i(calculator.commit_pkt_cast_o)

           ,.priv_mode_i(calculator.pipe_sys.csr.priv_mode_r)
           ,.mstatus_i(calculator.pipe_sys.csr.mstatus_lo)
           ,.mcause_i(calculator.pipe_sys.csr.mcause_lo)
           ,.scause_i(calculator.pipe_sys.csr.scause_lo)

           ,.ird_w_v_i(scheduler.iwb_pkt_cast_i.ird_w_v)
           ,.ird_addr_i(scheduler.iwb_pkt_cast_i.rd_addr)
           ,.ird_data_i(scheduler.iwb_pkt_cast_i.rd_data)

           ,.frd_w_v_i(scheduler.fwb_pkt_cast_i.frd_w_v)
           ,.frd_addr_i(scheduler.fwb_pkt_cast_i.rd_addr)
           ,.frd_data_i(scheduler.fwb_pkt_cast_i.rd_data)
           );

      bind bp_be_dcache
        bp_nonsynth_cache_tracer
         #(.bp_params_p(bp_params_p)
          ,.assoc_p(dcache_assoc_p)
          ,.sets_p(dcache_sets_p)
          ,.block_width_p(dcache_block_width_p)
          ,.fill_width_p(dcache_fill_width_p)
          ,.trace_file_p("dcache"))
         dcache_tracer
          (.clk_i(clk_i & testbench.dcache_trace_en_lo)
           ,.reset_i(reset_i)
           ,.freeze_i(cfg_bus_cast_i.freeze)

           ,.mhartid_i(cfg_bus_cast_i.core_id)

           ,.v_tl_r(v_tl_r)

           ,.v_tv_r(v_tv_r)
           ,.addr_tv_r(paddr_tv_r)
           ,.lr_miss_tv(lr_miss_tv)
           ,.sc_op_tv_r(decode_tv_r.sc_op)
           ,.sc_success(sc_success)

           ,.cache_req_v_o(cache_req_v_o)
           ,.cache_req_o(cache_req_o)

           ,.cache_req_metadata_o(cache_req_metadata_o)
           ,.cache_req_metadata_v_o(cache_req_metadata_v_o)

           ,.cache_req_complete_i(cache_req_complete_i)

           ,.v_o(early_v_o)
           ,.load_data(early_data_o[0+:65])
           ,.cache_miss_o('0)
           ,.wt_req(wt_req)
           ,.store_data(st_data_tv_r[0+:dword_width_gp])

           ,.data_mem_v_i(data_mem_v_li)
           ,.data_mem_pkt_v_i(data_mem_pkt_v_i)
           ,.data_mem_pkt_i(data_mem_pkt_i)
           ,.data_mem_pkt_yumi_o(data_mem_pkt_yumi_o)

           ,.tag_mem_v_i(tag_mem_v_li)
           ,.tag_mem_pkt_v_i(tag_mem_pkt_v_i)
           ,.tag_mem_pkt_i(tag_mem_pkt_i)
           ,.tag_mem_pkt_yumi_o(tag_mem_pkt_yumi_o)

           ,.stat_mem_pkt_v_i(stat_mem_pkt_v_i)
           ,.stat_mem_pkt_i(stat_mem_pkt_i)
           ,.stat_mem_pkt_yumi_o(stat_mem_pkt_yumi_o)
           );

      bind bp_fe_icache
        bp_nonsynth_cache_tracer
         #(.bp_params_p(bp_params_p)
          ,.assoc_p(icache_assoc_p)
          ,.sets_p(icache_sets_p)
          ,.block_width_p(icache_block_width_p)
          ,.fill_width_p(icache_fill_width_p)
          ,.trace_file_p("icache"))
         icache_tracer
          (.clk_i(clk_i & testbench.icache_trace_en_lo)
           ,.reset_i(reset_i)

           ,.freeze_i(cfg_bus_cast_i.freeze)
           ,.mhartid_i(cfg_bus_cast_i.core_id)

           ,.v_tl_r(v_tl_r)

           ,.v_tv_r(v_tv_r)
           ,.addr_tv_r(paddr_tv_r)
           ,.lr_miss_tv(1'b0)
           ,.sc_op_tv_r(1'b0)
           ,.sc_success(1'b0)

           ,.cache_req_v_o(cache_req_v_o)
           ,.cache_req_o(cache_req_o)

           ,.cache_req_metadata_o(cache_req_metadata_o)
           ,.cache_req_metadata_v_o(cache_req_metadata_v_o)

           ,.cache_req_complete_i(cache_req_complete_i)

           ,.v_o(data_v_o)
           ,.load_data(65'(data_o))
           ,.cache_miss_o('0)
           ,.wt_req()
           ,.store_data(dword_width_gp'(0))

           ,.data_mem_v_i(data_mem_v_li)
           ,.data_mem_pkt_v_i(data_mem_pkt_v_i)
           ,.data_mem_pkt_i(data_mem_pkt_i)
           ,.data_mem_pkt_yumi_o(data_mem_pkt_yumi_o)

           ,.tag_mem_v_i(tag_mem_v_li)
           ,.tag_mem_pkt_v_i(tag_mem_pkt_v_i)
           ,.tag_mem_pkt_i(tag_mem_pkt_i)
           ,.tag_mem_pkt_yumi_o(tag_mem_pkt_yumi_o)

           ,.stat_mem_pkt_v_i(stat_mem_pkt_v_i)
           ,.stat_mem_pkt_i(stat_mem_pkt_i)
           ,.stat_mem_pkt_yumi_o(stat_mem_pkt_yumi_o)
           );

      bind bp_core_minimal
        bp_nonsynth_vm_tracer
         #(.bp_params_p(bp_params_p))
         vm_tracer
          (.clk_i(clk_i & testbench.vm_trace_en_lo)
           ,.reset_i(reset_i)
           ,.freeze_i(be.calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)

           ,.mhartid_i(be.calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)

           ,.itlb_clear_i(fe.immu.tlb.flush_i)
           ,.itlb_fill_v_i(fe.immu.tlb.w_v_li)
           ,.itlb_fill_g_i(fe.immu.tlb.entry.gigapage)
           ,.itlb_vtag_i(fe.immu.tlb.vtag_i)
           ,.itlb_entry_i(fe.immu.tlb.entry_i)
           ,.itlb_r_v_i(fe.immu.tlb.r_v_li)

           ,.dtlb_clear_i(be.calculator.pipe_mem.dmmu.tlb.flush_i)
           ,.dtlb_fill_v_i(be.calculator.pipe_mem.dmmu.tlb.w_v_li)
           ,.dtlb_fill_g_i(be.calculator.pipe_mem.dmmu.tlb.entry.gigapage)
           ,.dtlb_vtag_i(be.calculator.pipe_mem.dmmu.tlb.vtag_i)
           ,.dtlb_entry_i(be.calculator.pipe_mem.dmmu.tlb.entry_i)
           ,.dtlb_r_v_i(be.calculator.pipe_mem.dmmu.tlb.r_v_li)
           );

      bind bp_core_minimal
        bp_nonsynth_core_profiler
         #(.bp_params_p(bp_params_p))
         core_profiler
          (.clk_i(clk_i & testbench.core_profile_en_lo)
           ,.reset_i(reset_i)
           ,.freeze_i(be.calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)

           ,.mhartid_i(be.calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)

           ,.fe_wait_stall(fe.is_wait)
           ,.fe_queue_stall(~fe.fe_queue_ready_i)

           ,.itlb_miss(fe.itlb_miss_r)
           ,.icache_miss(~fe.icache.ready_o)
           ,.icache_rollback(fe.icache_miss)
           ,.icache_fence(fe.icache.fencei_req)
           ,.branch_override(fe.pc_gen.ovr_taken & ~fe.pc_gen.ovr_ret)
           ,.ret_override(fe.pc_gen.ovr_ret)

           ,.fe_cmd(fe.fe_cmd_yumi_o & ~fe.attaboy_v)
           ,.fe_cmd_fence(be.director.suppress_iss_o)

           ,.mispredict(be.director.npc_mismatch_v)

           ,.dtlb_miss(be.calculator.pipe_mem.dtlb_miss_v)
           ,.dcache_miss(~be.calculator.pipe_mem.dcache.ready_o)
           ,.dcache_rollback(be.scheduler.commit_pkt_cast_i.rollback)
           ,.long_haz(be.detector.long_haz_v)
           ,.exception(be.director.commit_pkt_cast_i.exception | be.director.commit_pkt_cast_i.satp)
           ,.eret(be.director.commit_pkt_cast_i.eret)
           ,._interrupt(be.director.commit_pkt_cast_i._interrupt)
           ,.control_haz(be.detector.control_haz_v)
           ,.data_haz(be.detector.data_haz_v)
           ,.load_dep((be.detector.dep_status_r[0].emem_iwb_v
                       | be.detector.dep_status_r[0].fmem_iwb_v
                       | be.detector.dep_status_r[1].fmem_iwb_v
                       | be.detector.dep_status_r[0].emem_fwb_v
                       | be.detector.dep_status_r[0].fmem_fwb_v
                       | be.detector.dep_status_r[1].fmem_fwb_v
                       ) & be.detector.data_haz_v
                      )
           ,.mul_dep((be.detector.dep_status_r[0].mul_iwb_v
                      | be.detector.dep_status_r[1].mul_iwb_v
                      | be.detector.dep_status_r[2].mul_iwb_v
                      ) & be.detector.data_haz_v
                     )
           ,.struct_haz(be.detector.struct_haz_v)
           ,.reservation(be.calculator.reservation_n)
           ,.commit_pkt(be.calculator.commit_pkt_cast_o)
           );

      bind bp_be_top
        bp_nonsynth_pc_profiler
         #(.bp_params_p(bp_params_p))
         pc_profiler
          (.clk_i(clk_i & testbench.pc_profile_en_lo)
           ,.reset_i(reset_i)
           ,.freeze_i(calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)

           ,.mhartid_i(calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)

           ,.commit_pkt(calculator.commit_pkt_cast_o)
           );

      bind bp_be_top
        bp_nonsynth_branch_profiler
         #(.bp_params_p(bp_params_p))
         branch_profiler
          (.clk_i(clk_i & testbench.branch_profile_en_lo)
           ,.reset_i(reset_i)
           ,.freeze_i(detector.cfg_bus_cast_i.freeze)

           ,.mhartid_i(detector.cfg_bus_cast_i.core_id)

           ,.fe_cmd_o(director.fe_cmd_o)
           ,.fe_cmd_yumi_i(director.fe_cmd_yumi_i)

           ,.commit_v_i(calculator.commit_pkt_cast_o.instret)
           );

      if (multicore_p)
        begin
          bind bp_cce_wrapper
            bp_me_nonsynth_cce_tracer
             #(.bp_params_p(bp_params_p))
             cce_tracer
              (.clk_i(clk_i & testbench.cce_trace_en_lo)
              ,.reset_i(reset_i)
              ,.freeze_i(cfg_bus_cast_i.freeze)

              ,.cce_id_i(cfg_bus_cast_i.cce_id)

              // To CCE
              ,.lce_req_i(lce_req_i)
              ,.lce_req_v_i(lce_req_v_i)
              ,.lce_req_yumi_i(lce_req_yumi_o)
              ,.lce_resp_i(lce_resp_i)
              ,.lce_resp_v_i(lce_resp_v_i)
              ,.lce_resp_yumi_i(lce_resp_yumi_o)

              // From CCE
              ,.lce_cmd_i(lce_cmd_o)
              ,.lce_cmd_v_i(lce_cmd_v_o)
              ,.lce_cmd_ready_i(lce_cmd_ready_i)

              // To CCE
              ,.mem_resp_i(mem_resp_i)
              ,.mem_resp_v_i(mem_resp_v_i)
              ,.mem_resp_yumi_i(mem_resp_yumi_o)

              // From CCE
              ,.mem_cmd_i(mem_cmd_o)
              ,.mem_cmd_v_i(mem_cmd_v_o)
              ,.mem_cmd_ready_i(mem_cmd_ready_i)
              );

          bind bp_lce
            bp_me_nonsynth_lce_tracer
              #(.bp_params_p(bp_params_p)
                ,.sets_p(sets_p)
                ,.assoc_p(assoc_p)
                ,.block_width_p(block_width_p)
                )
              lce_tracer
              (.clk_i(clk_i & testbench.lce_trace_en_lo)
              ,.reset_i(reset_i)
              ,.lce_id_i(lce_id_i)
              ,.lce_req_i(lce_req_o)
              ,.lce_req_v_i(lce_req_v_o)
              ,.lce_req_ready_i(lce_req_ready_i)
              ,.lce_resp_i(lce_resp_o)
              ,.lce_resp_v_i(lce_resp_v_o)
              ,.lce_resp_ready_i(lce_resp_ready_i)
              ,.lce_cmd_i(lce_cmd_i)
              ,.lce_cmd_v_i(lce_cmd_v_i)
              ,.lce_cmd_yumi_i(lce_cmd_yumi_o)
              ,.lce_cmd_o_i(lce_cmd_o)
              ,.lce_cmd_o_v_i(lce_cmd_v_o)
              ,.lce_cmd_o_ready_i(lce_cmd_ready_i)
              );
        end
    end

  bp_nonsynth_if_verif
   #(.bp_params_p(bp_params_p))
   if_verif
    ();

endmodule
