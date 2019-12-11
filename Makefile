.PHONY: lint test

all: lint test

lint: .bundle/vim-vimhelplint .bundle/vim-fugitive
	vint -s autoload ftdetect ftplugin syntax
	vim -esN --not-a-term --cmd 'set rtp+=.bundle/vim-vimhelplint' \
		-c 'set rtp+=.bundle/vim-fugitive' \
		-c 'filetype plugin on' \
		-c 'e doc/phabricator.txt' \
		-c 'verb VimhelpLintEcho' \
		-c q

test: .bundle/vader.vim
	cd test && vim -EsNu vimrc --not-a-term -c 'Vader! */*'

.bundle/vim-fugitive:
	git clone --depth 1 https://github.com/tpope/vim-fugitive .bundle/vim-fugitive
	vim -u NONE -c "helptags .bundle/vim-fugitive/doc" -c q

.bundle/vader.vim:
	git clone --depth 1 https://github.com/junegunn/vader.vim.git .bundle/vader.vim

.bundle/vim-vimhelplint:
	git clone --depth 1 https://github.com/machakann/vim-vimhelplint.git .bundle/vim-vimhelplint
