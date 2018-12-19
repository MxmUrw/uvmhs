NAME := uvmhs

.PHONY: interact
interact: $(NAME).cabal
	stack ghci $(NAME)

.PHONY: build
build: $(NAME).cabal
	stack build

.PHONY: build-profile
build-profile: $(NAME).cabal
	stack build --profile

.PHONY: install
install: $(NAME).cabal
	stack install

.PHONY: configure
configure: $(NAME).cabal

.PHONY: doc
doc:
	stack haddock
	cp -r `stack path --local-doc-root` ./

.PHONY: clean
clean:
	stack clean
	rm -f $(NAME).cabal

.PHONY: hoogle
hoogle:
	stack hoogle -- generate --local
	(sleep 1 && open http://localhost:8080/?scope=package%3A$(NAME)) &
	stack hoogle -- server --local --port=8080

$(NAME).cabal: package.yaml
	hpack --force

