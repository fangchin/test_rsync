#!/bin/bash
#
# GNU General Public License v3.0
#
# Name   : harness.sh - a test harness of the trsync.sh.
#
# Author : Chin Fang <fangchin@zettar.com>
#
# Purpose: To facilitate the use of the trsync.sh.
#
# Notes :  0. Owing to the well-known low data transfer performance of
#             rsync over long haul networks, regardless of the
#             available storage throughput, computing power, and
#             network bandwidth, only three test datasets are employed
#             for rsync and rsync+rsyncd tests to save time and be
#             practical.  Furthermore, for the same type of tests (LAN
#             or WAN), rsync, rsync+rsyncd, and parsyncft test can be
#             selected individually.
#          1. rsync is a good example of data movers designed without
#             high concurrency and scale-out considerations. Thus, it
#             is intrinsically incapable of dealing with high network
#             latency, even used in an aggregated manner via wrappers
#             such as parsyncfp. Its ability dealing with LOSF and
#             large files (e.g. 256GiB) is also poor as well.
#          2. Many other data moving tools bundled with Linux distros
#             suffer the same shortcomings, e.g. cp, scp, sftp, and
#             vsftp (server/client).
#          3. To use this harness and the trsync.sh, the parsyncfp
#             perl wrapper and its dependencies must be installed
#             first. Please see reference 0. below for more details.
#          4. If re-running a particular test is desired, the command
#             displayed with the -n option can be used easily.
#
# References:
#          0. https://github.com/hjmangalam/parsyncfp
#
# A few global variables. Contrary to a myth popular among newbie
# programmers, if judiciously employed, global variables simplify
# programming :D
#
test_type='lan'
ssh_port=
address=192.168.15.20
daemon=
src_data_dir=/var/local/zettar/zx/src_data # the source node's data dir
dst_data_dir=/var/local/zettar/zx/dst_data # the target node's data dir
output_dir=/var/tmp
run_wrapper=
iface=
ncore=$(nproc)
incore=$(echo "scale=1; sqrt($ncore)"|bc)
incore=$(echo "$incore"|awk '{print int($1)}')
verbose=
dry_run=

help()
{
    local help_str=''
    read -r -d '' help_str <<'EOF'
This script is a test harness for trsync.sh.  See trsync.sh -h for
details. A good way to learn how to use it is to try out the dry-run
mode -n first.  If re-running a particular test is desired, the
command displayed with the -n option can be used easily.

Command line options:
    -h show this help
    -t type of test: lan or wan
    -p the port for ssh connections
    -i target IPv4 address
    -C the upper bound of CPU cores utilized (positive integer only!)
    -S the path of the source directory with the desired hyperscale datasets
    -D the path of the destination directory
    -d connect to the target via rsync daemon (must be set up & named backup!)
    -o the path to the directory where the results are stored (def: /var/tmp)
    -P run the parsyncfp perl wrapper
    -I the interface to use. No effect without -P
    -v executed commands are displayed. Do not use for dry-runs
    -n dry-run; to print out tests that would have run

The usage (on the source node): 
# harness.sh [-h][-t test_type][-p ssh port][-i ipv4_address][-S src_data_dir]\
  [-D dst_data_dir][-o output_dir][-d][-P][-I iface][-v][-n]

Examples: 0. # harness.sh -t lan -p 4023 -i 10.10.2.1 \
               -S /data/zettar/zx/src -D /data/zettar/zx/dst
          1. # harness.sh -t lan -p 4023 -i 10.10.2.1 \
               -S /data/zettar/zx/src -D /data/zettar/zx/dst -d
          2. # harness.sh -t lan -p 4023 -i 10.10.2.1 \
               -S /data/zettar/zx/src -D /data/zettar/zx/dst -P -I eth200.4012

In the above examples
All runs are done using a custom ssh port 4023
0   shows to carry out a LAN test case using rsync only
1   shows to carry out a test case with rsync daemon on 
    10.10.2.1
2   shows to how to use the parsyncfp and the network interface eth200.4012
    to carry out a LAN test
EOF
    echo "$help_str"
    exit 0
}

do_sml()
{
    local cmd
    cmd=$1
    local out_file
    out_file=$2
    if [[ -z "$dry_run" ]]; then
	[[ "$verbose" ]] && date;echo "$cmd -r s | tee $out_file'_losf.out'"
	$cmd -r s | tee "$out_file"'_losf.out'
	[[ "$verbose" ]] && date;echo "$cmd -r m | tee $out_file'_medium.out'"
	$cmd -r m | tee "$out_file"'_medium.out'
	[[ "$verbose" ]] && date;echo "$cmd -r l | tee $out_file'_large.out'"
	$cmd -r l | tee "$out_file"'_large.out'
    else
	echo "$cmd -r s | tee $out_file'_losf.out'"
	echo "$cmd -r m | tee $out_file'_medium.out'"
	echo "$cmd -r l | tee $out_file'_large.out'"	
    fi
}

par_sml()
{
    local cmd
    cmd=$1
    local cmd_base
    cmd_base=$1
    local out_file
    out_file=$2
    local idx
    for idx in {0..5}
    do
	for n in $(seq "$incore" 2 "$ncore")
	do
	    echo "$n rsync instances"
	    cmd+="-r s -N $n -a $idx | tee ${out_file}_losf.$idx$n"
	    if [[ -z "$dry_run" ]]; then
		[[ "$verbose" ]] &&
		    date;echo "$cmd"
		$cmd
	    else
		echo "$cmd"
	    fi
	    cmd="$cmd_base"
	done
    done

    # Test parsyncfp medium
    idx=6
    for n in $(seq "$incore" 2 "$ncore")
    do
	echo "$n rsync instances"
	cmd+="-r m -N $n -a $idx | tee ${out_file}_medium.$n"
	if [[ -z "$dry_run" ]]; then
	    [[ "$verbose" ]] &&
		date;echo "$cmd"
	    $cmd
	else
	    echo "$cmd"
	fi
	cmd="$cmd_base"
    done

    # Test parsyncfp large
    idx=7
    for n in $(seq "$incore" 2 "$ncore")
    do
	echo "$n rsync instances"
	cmd+="-r l -N $n -a $idx | tee ${out_file}_large.$n"
	if [[ -z "$dry_run" ]]; then
	    [[ "$verbose" ]] &&
		date;echo "$cmd"
	    $cmd
	else
	    echo "$cmd"
	fi
	cmd="$cmd_base"
    done
}

lan_test()
{
    local cmd
    local out_file
    cmd="trsync.sh -i $address -S $src_data_dir -D $dst_data_dir "
    if ! [[ "$run_wrapper" ]]; then    
	# Test rsync by itself, using the 1048576x256KiB, 4096x256MiB,
	# and 4x256GiB
	out_file="$output_dir"/rsync_lan
	if [[ -z "$daemon" ]]; then
	    # Test rsync by itself, using the 1048576x256KiB, 4096x256MiB,
	    # and 4x256GiB
	    do_sml "$cmd" "$out_file"
	else   
	    # Test rsync and rsyncd, using the 1048576x256KiB,
	    # 4096x256MiB, and 4x256GiB
	    cmd+="-d"
	    do_sml "$cmd" "$out_file"
	fi
    else
	# Test parsyncfp LOSF. Iterate over six different sizes in this
	# range. Also iterate over the the core number from sqrt(nproc) to
	# nproc, incremented by 2
	out_file="$output_dir"/parsyncfp_lan
	cmd="trsync.sh -i $address -S $src_data_dir -D $dst_data_dir "
	cmd+="-P -I $iface "
	par_sml "$cmd" "$out_file"
    fi
}

wan_test()
{
    local cmd
    cmd="trsync.sh -i $address -S $src_data_dir -D $dst_data_dir "
    local out_file
    if ! [[ "$run_wrapper" ]]; then
	if ! [[ "$daemon" ]]; then  
	    # Test rsync by itself, using the 1048576x256KiB, 4096x256MiB,
	    # and 4x256GiB
	    out_file="$output_dir"/rsync_wan
	    do_sml "$cmd" "$out_file"
	else
	    # Test rsync and rsyncd, using the 1048576x256KiB,
	    # 4096x256MiB, and 4x256GiB
	    out_file="$output_dir"/rsyncd_wan
	    cmd+="-d"
	    do_sml "$cmd" "$out_file"
	fi
    else
	# Test parsyncfp LOSF. Iterate over six different sizes in this
	# range. Also iterate over the the core number from sqrt(nproc) to
	# nproc, incremented by 2
	out_file="$output_dir"/parsyncfp_wan
	cmd="trsync.sh -i $address -S $src_data_dir -D $dst_data_dir "
	cmd+="-P -I $iface "	
	par_sml "$cmd" "$out_file"
    fi
}

verify_test_type()
{
    local type
    type=$1
    if [[ "$type" != 'lan' ]] && [[ "$type" != 'wan' ]]; then
	echo "Only LAN or WAN test supported. Abort!"
        exit 1
    fi
}

verify_directory_exists()
{
    local dir
    dir=$1
    if [[ "$(cd "$dir")" -ne 0 ]]; then
        msg="$dir does not exist. Abort!"
        echo "$msg"
        exit 1
    fi
}

verify_ssh_port()
{
    # Note, ssh_port is a global variable :)
    local msg
    
    if ! [[ "$ssh_port" =~ ^[1-9][0-9]*$ ]]; then
        msg="ssh_port must be a positive integer. Abort!"
        echo "$msg"
        exit 1
    fi     
}

verify_ncore()
{
    # Note, ncore is a global variable :)
    local msg
    
    if ! [[ "$ncore" =~ ^[1-9][0-9]*$ ]]; then
        msg="the number of cores must be a positive integer. Abort!"
        echo "$msg"
        exit 1
    fi     
}


verify_iface()
{
    # Note, iface is a global variable :)
    local msg
    if /sbin/ethtool "$iface" | grep -q "Link detected: yes"; then
        :
    else
        echo "$iface not online. Abort!"
        exit 1
    fi   
}

# main()
{
    begin_test=$(date +"%s")
    while getopts "ht:p:i:C:S:D:do:PI:vn" opt; do
        case $opt in
            h)  help
                ;;
            t)  test_type=$OPTARG
                verify_test_type "$test_type"
                ;;
            p)  ssh_port=$OPTARG
                verify_ssh_port
                ;;
            i)  address=$OPTARG
                if ! [[ "$address" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    echo "Error: the given target address is invalid"
                    exit 1
                fi            
                ;;
            C)  ncore=$OPTARG
                verify_ncore
                ;;	    
            S) src_data_dir=$OPTARG
               if ! [[ -d "$src_data_dir" ]]; then
                   echo "Error: the source data directory doesn't exist!"
                   exit 1
               fi
               ;;
            D) dst_data_dir=$OPTARG # this is on the destination node!
               ;;
            d) daemon=true
               ;;
            o) output_dir=$OPTARG
	       verify_directory_exists "$output_dir"
               ;;
            P) run_wrapper=1
               ;;
            I) iface=$OPTARG
               if [[ -z "$run_wrapper" ]]; then
                   echo "This option takes no effect without -P. Abort!"
                   exit 1
               fi              
               verify_iface
               ;;
	    v) verbose=1
	       if [[ "$dry_run" ]]; then
		   echo "Warning: verbose mode shouldn't be used for dry-runs"
	       fi
	       ;;
	    n) dry_run=1
	       ;;	    
            *)  echo "Error: invalid option given!"
                exit 2
                ;;
        esac
    done
    if [[ "$ssh_port" ]]; then
        export RSYNC_RSH="ssh -p $ssh_port"
    fi     
    if [[ "$test_type" == 'lan' ]]; then
        lan_test
    else
        wan_test
    fi
    end_test=$(date +"%s")
    total_test_time=$((end_test-begin_test))
    echo ""
    ending="second"
    if [[ "$total_test_time" -gt 1 ]]; then
        ending="seconds"
    fi
    echo "==> TOTAL test time (with cleaning): $total_test_time $ending"
    exit 0
} # end of main()
