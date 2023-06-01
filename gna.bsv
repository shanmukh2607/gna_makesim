package gna;
// imports
import Vector :: *;
import RegFile :: * ;

interface Ifc_gna;
    // methods
    method Action get_input_size(int img_height, int img_width, int num_c); // n channels
    method Action get_weight_size(int kernel_height, int kernel_width, int m_filters); // m filters of size kh x kl x n
    method int check_kkl();
    method int check_n();
    method int check_l();
    method int check_kkh();
    method int check_m();
    method int check_h();
    method int done();
    method Bit#(4) state_check();
    method int read_check();
endinterface: Ifc_gna

(*synthesize*)

module mkGNA(Ifc_gna);
    // Tiling parameters of image; Design choice
    // h = 1;  // Input tile size in heigh dim
    Integer tn = 1; // Input tile size in channel dim
    Integer tl = 4; // Input tile size in length dim 

    // Input size params
    Reg#(Bit#(32)) ih <- mkReg(0);
    Reg#(Bit#(32)) il <- mkReg(0);
    Reg#(Bit#(32)) nc <- mkReg(0);

    // Weight size parameters should be imported hence should be declared in hardware
    Reg#(Bit#(32)) kh <- mkReg(0);
    Reg#(Bit#(32)) kl <- mkReg(0);
    Reg#(Bit#(32)) mf <- mkReg(0);
    Integer tm = 4; // Number of filters chosen in weight tile
    // Design choice to make tm = tl

    // Weight Buffer
    Integer wbuf_size = 36;//4992; // now reduced to 19.5KB  // 54KB
    Reg#(Bit#(32)) weight_buffer[wbuf_size];
    
    for(Integer i=0; i< wbuf_size; i = i+1) begin
        weight_buffer[i] <- mkReg(0);
    end

    RegFile#(Bit#(32), Bit#(32)) weight_input <- mkRegFileLoad("weight.txt",0,fromInteger(wbuf_size) - 1);
    Reg#(Bit#(32)) w_count <- mkReg(0);

    // Image Buffer
    Integer ibuf_size =  16;//3072;   // now reduced to 12KB // 19.5KB
    Reg#(Bit#(32)) image_buffer[ibuf_size];

    for(Integer i=0; i< ibuf_size; i = i+1) begin
        image_buffer[i] <- mkReg(0);
    end

    RegFile#(Bit#(32), Bit#(32)) image_input <- mkRegFileLoad("image.txt",0,fromInteger(ibuf_size) - 1);
    Reg#(Bit#(32)) i_count <- mkReg(0);

    // Output Buffer
    Integer obuf_size = 324;//10368; // now reduced to 40.5 KB // 136.5 KB
    Reg#(Bit#(32)) output_buffer[4][9][9];

    for(Integer i=0; i< 4; i = i+1) begin
        for(Integer j = 0; j < 9; j = j+1) begin
            for(Integer k = 0; k < 9; k = k + 1) begin
                output_buffer[i][j][k] <- mkReg(0);
            end
        end
    end


    // Cold Buffer
    Integer c1_size = 9;//134;  // now reduced to 8.375 KB // 16KB
    Reg#(Bit#(32)) c1_buffer[tm][c1_size];

    for(Integer i=0; i< tm; i = i+1) begin
        for(Integer j = 0; j < c1_size; j = j+1) begin
        c1_buffer[i][j] <- mkReg(0);
        end
    end

    Integer c2_size = 400;//4288;     // 32 KB
    Reg#(Bit#(32)) c2_buffer[4][1][9];

    for(Integer i=0; i< 4; i = i+1) begin
        for(Integer j = 0; j < 1; j = j +1) begin
            for(Integer k = 0; k < c1_size; k = k + 1) begin
                c2_buffer[i][j][k] <- mkReg(0);
            end
        end
    end

    // Tiled Input
    // Reg#(Bit#(32)) image_tile[tl]; // Tn x Tl x 1
    Vector#(4, Reg#(Bit#(32))) image_tile <- replicateM(mkReg(0));

    // Tiled Kernel
    Vector#(4, Reg#(Bit#(32))) weight_tile <- replicateM(mkReg(0)); 
    // Reg#(Bit#(32)) weight_tile[tm]; // Tn x Tm x Kl x1  (xKl is looped, HW re-use)

    // Compute status register
    Reg#(Bit#(4)) state <- mkReg(0);

    // Coordinator
    Reg#(Bit#(32)) r <- mkReg(0);
    Reg#(Bit#(32)) c <- mkReg(0);

    // Output dims
    Reg#(Bit#(32)) rmax <- mkReg(0);
    Reg#(Int#(32)) lol <- mkReg(0);
    Reg#(Bit#(32)) cmax <- mkReg(0);

    // Counters for iterators
    Reg#(Bit#(32)) h <- mkReg(0); // Loop H
    Reg#(Bit#(32)) m <- mkReg(0); // Loop M
    Reg#(Bit#(32)) kkh <- mkReg(0); // Loop Kh
    Reg#(Bit#(32)) l <- mkReg(0); // Loop L
    Reg#(Bit#(32)) kkl <- mkReg(0); // Loop Kl
    Reg#(Bit#(32)) n <- mkReg(0); // Loop N


    rule initialize(state == 0);
        // op dims calculation
        rmax <= 2*ih + kh -2;
        cmax <= 2*il + kl -2;

        // reset iterators
        h <= 0;
        m <= 0;
        kkh <= 0;
        l <= 0;
        kkl <= 0;
        n <= 0;
        i_count <= 0;
        w_count <= 0;

        if(rmax != 0) state <= state + 1;
    endrule

    rule set_buffer(state == 1);          // 128b data transfer in 1 cycle
        if(i_count < ih*il*nc) begin
            image_buffer[i_count] <=      image_input.sub(i_count);
            image_buffer[i_count + 1] <=  image_input.sub(i_count + 1);
            image_buffer[i_count + 2] <=  image_input.sub(i_count + 2);
            image_buffer[i_count + 3] <=  image_input.sub(i_count + 3);
            i_count <= i_count + 4;
            end

        if(w_count < kh*kl*nc*mf) begin
            weight_buffer[w_count] <=     weight_input.sub(w_count);
            weight_buffer[w_count + 1] <= weight_input.sub(w_count + 1);
            weight_buffer[w_count + 2] <= weight_input.sub(w_count + 2);
            weight_buffer[w_count + 3] <= weight_input.sub(w_count + 3);
            w_count <= w_count + 4;
        end
        if((w_count >= kh*kl*nc*mf) && (i_count >= ih*il*nc)) 
        state <= state + 1;
    endrule


    rule increment((kkl == kl + 1) && (state == 2));
        if(n < nc) 
            begin
            if(n != nc - 1) n <= n + 1;         // Loop N
            else n <= 0; // reset n
            end

        // reset kkl
        kkl <= 0;

        if((l < il) && (n == nc -1))            // Loop L
            begin
                if(l < il - fromInteger(tl)) l <= l + fromInteger(tl);
                else 
                    begin 
                        l <= 0; // reset l
                        // Also reset the cold-1 buffer: Used for Stitching o/p of all tiles in a row
                        for(int aa = 0; aa < fromInteger(tm); aa = aa + 1) 
                            begin
                                for(int bb = 0; bb < fromInteger(c1_size); bb = bb + 1) begin
                                    c1_buffer[aa][bb] <= 0;
                                end
                            end

                        // Set c2_buffer
                        if(kkh > 1) begin
                            for(int aa = 0; (aa < fromInteger(tm)) && (m + pack(aa) < mf); aa = aa + 1) begin
                                for(int bb = 0; bb < fromInteger(c1_size); bb = bb + 1) begin
                                    c2_buffer[m + pack(aa)][kkh - 2][pack(bb)] <= output_buffer[m + pack(aa)][r][pack(bb)];
                                end
                            end
                        end

                        if(kkh < kh -2) begin
                            for(int aa = 0; (aa < fromInteger(tm)) && (m + pack(aa) < mf); aa = aa + 1) begin
                                for(int bb = 0; bb < fromInteger(c1_size); bb = bb + 1) begin
                                     output_buffer[m + pack(aa)][r][pack(bb)] <= output_buffer[m + pack(aa)][r][pack(bb)] + c2_buffer[m + pack(aa)][kkh][pack(bb)];
                                end
                            end
                        end
                            
                        if(kkh < kh - 1) begin
                            kkh <= kkh + 1;    // Loop Kh
                        end

                        else 
                            begin
                                kkh <= 0; // reset kkh
                                if(m < mf)              // Loop M
                                    begin
                                        if(m < mf - fromInteger(tm)) m <= m + fromInteger(tm);
                                        else
                                            begin
                                                m <= 0; // reset m
                                                if(h < ih - 1) h <= h + 1;     // Loop H
                                                else begin
                                                    state <= state + 1;
                                                    h <= 0;
                                                end
                                            end
                                    end

                            end
                    end
            end

    endrule

    
    rule compute_CE((kkl < kl + 1) && (state == 2));

        if(kkl == 0) 
        begin
            // load image tile
            // loaded only once for kkl = 0 to kl-1  iteration
            for(int pos = 0; pos < fromInteger(tl); pos = pos + 1)
                begin
                    if(l + pack(pos) < il) image_tile[pos] <= image_buffer[n*ih*il + h*il + l + pack(pos)]; 
                    else image_tile[pos] <= 0;
                end

            // load weight tile  for kkl = 0  
            for(int loc = 0; loc < fromInteger(tm); loc = loc + 1)
                begin
                    if(m + pack(loc) < mf) weight_tile[loc] <= weight_buffer[(m + pack(loc))*nc*kh*kl + n*kh*kl + kkh*kl + kkl];
                    else weight_tile[loc] <= 0;
                end
        
            // Compute coordinate w.r.t O0
            r <= h*2 + kkh;  // Doesn't change when this rule is running
            c <= l*2 + kkl;
        end

        
        if((kkl > 0) && (kkl < kl)) begin
            // load weight tile
            // loaded every iter for kkl = 0 to kl-1
            for(int loc = 0; loc < fromInteger(tm); loc = loc + 1)
                begin
                    if(m + pack(loc) < mf) weight_tile[loc] <= weight_buffer[(m + pack(loc))*nc*kh*kl + n*kh*kl + kkh*kl + kkl];
                    else weight_tile[loc] <= 0;
                end

            // computation 
            // In kkl-th iteration, tiles contain data for (kkl - 1) weights

            for(int w_index = 0; w_index < fromInteger(tm); w_index = w_index + 1) begin
                for(int i_index = 0; i_index < fromInteger(tl); i_index = i_index + 1) begin
                // Accumulator + Cold Buffer
                    // output_buffer[m*rmax*cmax + pack(w_index)*rmax*cmax + r*cmax + c + pack(i_index)*2 + kkl - 1] 
                    output_buffer[m + pack(w_index)][r][2*l + pack(i_index)*2 + kkl - 1] <= image_tile[i_index] * weight_tile[w_index] + c1_buffer[w_index][2*l + pack(i_index)*2 + kkl - 1];
                    c1_buffer[w_index][2*l + pack(i_index)*2 + kkl - 1] <= image_tile[i_index] * weight_tile[w_index] + c1_buffer[w_index][2*l + pack(i_index)*2 + kkl - 1];
                end
            end


        end
        

        // computation of last iter
        // In kl-th iteration, tiles contain data for (kl - 1) weights

        if(kkl == kl) begin
            for(int w_index = 0; w_index < fromInteger(tm); w_index = w_index + 1)
            begin
                for(int i_index = 0; i_index < fromInteger(tl); i_index = i_index + 1)
                begin
                // Accumulator + Cold Buffer
                    // output_buffer[m*rmax*cmax + pack(w_index)*rmax*cmax + r*cmax + 2*l + pack(i_index)*2 + kkl - 1] 
                    output_buffer[m + pack(w_index)][r][2*l + pack(i_index)*2 + kkl - 1]<= image_tile[i_index] * weight_tile[w_index] + c1_buffer[w_index][2*l + pack(i_index)*2 + kkl - 1];
                    c1_buffer[w_index][2*l + pack(i_index)*2 + kkl - 1] <= image_tile[i_index] * weight_tile[w_index] + c1_buffer[w_index][2*l + pack(i_index)*2 + kkl - 1];
                end
            end
        end

        // Update kkl
        kkl <= kkl + 1;


    endrule

    rule display_output (state == 3);

    for(int i = 0; i < 4; i = i + 1) begin
        for(int j = 0; j < 9; j = j + 1) begin
            for(int k = 0; k <9; k = k + 1) begin
                if(output_buffer[i][j][k][31] == 0)$display("%d",output_buffer[i][j][k]);
                else $display("-%d", 32'hFFFFFFFF - output_buffer[i][j][k]);
            end
        end
    end

    endrule

    

    // methods declaration
    
    method Action get_input_size(int img_height, int img_width, int num_c); 
        ih <= pack(img_height);
        il <= pack(img_width);
        nc <= pack(num_c);
    endmethod


    method Action get_weight_size(int kernel_height, int kernel_width, int m_filters);
        kh <= pack(kernel_height);
        kl <= pack(kernel_width);
        mf <= pack(m_filters);
    endmethod

    method int check_kkl();
        return unpack(kkl);
    endmethod

    method int check_n();
        return unpack(n);
    endmethod

    method int check_l();
        return unpack(l);
    endmethod

    method int check_kkh();
        return unpack(kkh);
    endmethod

    method int check_m();
        return unpack(m);
    endmethod

    method int check_h();
        return unpack(h);
    endmethod

    method int done();
        if(state == 3) return 2;
        else return 1;
    endmethod

    method Bit#(4) state_check();
        return state;
    endmethod

    method int read_check();
        return unpack(c1_buffer[0][4]);
    endmethod


endmodule


endpackage