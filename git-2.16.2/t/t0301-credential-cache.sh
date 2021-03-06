#!/bin/sh

test_description='credential-cache tests'
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-credential.sh

test -z "$NO_UNIX_SOCKETS" || {
	skip_all='skipping credential-cache tests, unix sockets not available'
	test_done
}

# don't leave a stale daemon running
trap 'code=$?; git credential-cache exit; (exit $code); die' EXIT

# test that the daemon works with no special setup
helper_test cache

test_expect_success 'socket defaults to ~/.cache/git/credential/socket' '
	test_when_finished "
		git credential-cache exit &&
		rmdir -p .cache/git/credential/
	" &&
	test_path_is_missing "$HOME/.git-credential-cache" &&
	test -S "$HOME/.cache/git/credential/socket"
'

XDG_CACHE_HOME="$HOME/xdg"
export XDG_CACHE_HOME
# test behavior when XDG_CACHE_HOME is set
helper_test cache

test_expect_success "use custom XDG_CACHE_HOME if set and default sockets are not created" '
	test_when_finished "git credential-cache exit" &&
	test -S "$XDG_CACHE_HOME/git/credential/socket" &&
	test_path_is_missing "$HOME/.git-credential-cache/socket" &&
	test_path_is_missing "$HOME/.cache/git/credential/socket"
'
unset XDG_CACHE_HOME

test_expect_success 'credential-cache --socket option overrides default location' '
	test_when_finished "
		git credential-cache exit --socket \"\$HOME/dir/socket\" &&
		rmdir \"\$HOME/dir\"
	" &&
	check approve "cache --socket \"\$HOME/dir/socket\"" <<-\EOF &&
	protocol=https
	host=example.com
	username=store-user
	password=store-pass
	EOF
	test -S "$HOME/dir/socket"
'

test_expect_success "use custom XDG_CACHE_HOME even if xdg socket exists" '
	test_when_finished "
		git credential-cache exit &&
		sane_unset XDG_CACHE_HOME
	" &&
	check approve cache <<-\EOF &&
	protocol=https
	host=example.com
	username=store-user
	password=store-pass
	EOF
	test -S "$HOME/.cache/git/credential/socket" &&
	XDG_CACHE_HOME="$HOME/xdg" &&
	export XDG_CACHE_HOME &&
	check approve cache <<-\EOF &&
	protocol=https
	host=example.com
	username=store-user
	password=store-pass
	EOF
	test -S "$XDG_CACHE_HOME/git/credential/socket"
'

test_expect_success 'use user socket if user directory exists' '
	test_when_finished "
		git credential-cache exit &&
		rmdir \"\$HOME/.git-credential-cache/\"
	" &&
	mkdir -p -m 700 "$HOME/.git-credential-cache/" &&
	check approve cache <<-\EOF &&
	protocol=https
	host=example.com
	username=store-user
	password=store-pass
	EOF
	test -S "$HOME/.git-credential-cache/socket"
'

test_expect_success SYMLINKS 'use user socket if user directory is a symlink to a directory' '
	test_when_finished "
		git credential-cache exit &&
		rmdir \"\$HOME/dir/\" &&
		rm \"\$HOME/.git-credential-cache\"
	" &&
	mkdir -p -m 700 "$HOME/dir/" &&
	ln -s "$HOME/dir" "$HOME/.git-credential-cache" &&
	check approve cache <<-\EOF &&
	protocol=https
	host=example.com
	username=store-user
	password=store-pass
	EOF
	test -S "$HOME/.git-credential-cache/socket"
'

helper_test_timeout cache --timeout=1

# we can't rely on our "trap" above working after test_done,
# as test_done will delete the trash directory containing
# our socket, leaving us with no way to access the daemon.
git credential-cache exit

test_done
