SVGFILES:= ack.svg ack_eob.svg mid_burst_seq_error.svg seq_error.svg time_error.svg

doc: $(SVGFILES)

%.svg: %.mscgen
	mscgen -T svg -i $< -o $@

.PHONY: doc
