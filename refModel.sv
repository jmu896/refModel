module refModel (
    // OUTPORT (can also use 'output logic' instead of 'output reg')
    output logic [31:0] o_tdata1,
    output logic [31:0] o_tdata2,
    output logic        o_tvalid,
    // INPORT
    input  logic        o_tready, // Recommended to use logic for inputs too
    input  logic        reset,
    input  logic        sClk, // reloj de muestreo -> sampleClock
    input  logic [63:0] vita_time,
    input  logic [63:0] vita_time_trigger,
    input  logic [31:0] len_PRI,
    input  logic [31:0] duration_wave,
    input  logic [2:0]  type_wave, // 0: chirp 1: tono 2: rampa
    input  logic        sRun
);

    // FSM State Definition using enum (SystemVerilog)
    typedef enum logic [1:0] { // Explicitly define bit-width for synthesis
        WAIT_FOR_PARAM,
        WAVE_GEN
    } state_t;

    state_t state; // FSM state register
    logic [2:0] i; // Counter -- updates outputs every 3 sClk posedges
    int sampleCounter;
    logic waveDone; // Flag to indicate wave generation is complete
    // vuelca lectura para 
    logic [2:0] typeWave;
    logic [31:0] lenPRI;
    logic [31:0] durationWave;
    // Datos definidos desde fuera del modulo
    int bw = 100000;  // Ancho de banda del chirp
    int f_tone = 10000;  // Frecuencia del tono
    logic [31:0] data1;  //temporal para volcar dato calculado a salida
    logic [31:0] data2;  // ||
    
    
    //  FSM State Register
    always_ff @(posedge sClk) begin
        if (reset) begin
            state <= WAIT_FOR_PARAM;
        end else begin
            case(state)
                WAIT_FOR_PARAM: begin
                    if (sRun) begin
                        state <= WAVE_GEN;
                    end else begin
                        state <= WAIT_FOR_PARAM;
                    end
                end

                WAVE_GEN: begin
                    if (!sRun || waveDone) begin // Condition to go back to waiting
                        state <= WAIT_FOR_PARAM;
                    end else begin
                        state <= WAVE_GEN; // Stay in WaveGen
                    end
                end

                default: state <= WAIT_FOR_PARAM; // Handle unexpected states
            endcase
        end
    end

    // Output Logic (registered outputs often in the same always_ff block or separate)
    // For simplicity, let's keep outputs registered and reset here.
    always_ff @(posedge sClk) begin
        if (reset) begin
            o_tdata1 <= 0;
            o_tdata2 <= 0;
            o_tvalid <= 0;
            i <= 0;
            waveDone <= 0;
        end else begin
            // Default assignments (combinational logic could also drive these)
            o_tdata1 <= o_tdata1; // Retain previous value if not explicitly assigned
            o_tdata2 <= o_tdata2;
            o_tvalid <= 0; // Default to low unless asserted

            case(state)
                WAIT_FOR_PARAM: begin
                    i <= 0; // Reset counter when waiting
                    waveDone <= 0; // Reset waveDone
                    sampleCounter<=0;
                    if(sRun) begin // vuelca parametros de entrada antes de empezar a generar onda
                        typeWave<=type_wave;
                        lenPRI<=len_PRI;
                        durationWave<=duration_wave;
                    end
                end

                WAVE_GEN: begin
                    if (!waveDone) begin // Only process if wave isn't done
                        if (o_tready) begin
                            i++;
                            if(i>=2) begin // cada 3 muestras actualiza salida
                                sampleCounter++;
                                if(typeWave==0) begin // chirp
                                    //////////////
                                end else if(typeWave==1) begin // tono
                                    // CALCULA SENO CORRESPONDIENTE AL NUMERO DE MUESTRA 
                                    // SEPARA DATO DEL SENO PARA LLEVARLO A DATA1 Y DATA2
                                end else begin // rampa 
                                    ///////////
                                end
                                
                                if(sampleCounter<=durationWave) begin // si es menor al duration_wave leido antes, pasa dato
                                    o_tdata1 <= data1;
                                    o_tdata2 <= data2;
                                    o_tvalid <= 1;
                                end else begin // si no, dato escrito es 0.
                                    o_tdata1 <= 0;
                                    o_tdata2 <= 0;
                                    o_tvalid <= 1;
                                end
                          // Check for completion based on duration_wave
                                if (sampleCounter >= lenPRI - 1) begin
                                    waveDone <= 1;
                                end
                            end
                        end
                        // If not o_tready, o_tvalid remains 0 from default, and data holds
                    end else begin // waveDone is asserted, go back to idle logic
                        o_tvalid <= 0; // Ensure valid is low when wave is done
                        i <= 0; // Reset for next wave
                    end
                end
            endcase
        end
    end

endmodule