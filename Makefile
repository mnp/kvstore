target = kvstore

default: $(target)
	ponyc

.PHONY: $(target)

clean:
	@rm -f $(target)
