scriptdir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
graphmap_parse=
webgraphz_convert=
terashuf=
graphs=(livejournal twitter webuk_2007_05)
action=$1
if [ -z "${action}" ]; then
  action=download
fi

name_from_url() {
  local url=$1
  echo ${url} | awk -F'/' '{print $NF}'
}

xwget() {
  local url=$1 
  local download_name=$(name_from_url ${url})

  if [ -f ${download_name} ]; then
    echo "${download_name} already downloaded"
  else
    echo "downloading ${download_name}"
    wget ${url}
    if [ -f ${download_name} ]; then
      echo "${download_name} successfully downloaded"
    else
      echo "failed to download ${download_name} from ${url}"
      exit
    fi
  fi
}

decompress() {
  local name=$1
  local dname=

  if [ ! -f ${name} ]; then
    echo "${name} not exist"
    exit
  else
    if [[ ${name} == *.tar.gz ]]; then
      echo "to be done"
    elif [[ ${name} == *.gz ]]; then
      gzip -d ${name}
      dname=${name%.gz}
    else
      echo "Unknown compressed file suffix: ${name}"
      exit
    fi
  fi

  if [ -f ${dname} ]; then
    echo "${dname} successfully decompressed"
  else
    echo "failed to decompress ${dname}"
    exit
  fi
}

check_rust_env() {
  if [ -z "$(which rustc)" ]; then
    echo "Rust env check failed: rustc not found."
    exit
  fi
  if [ -z "$(which cargo)" ]; then
    echo "Rust env check failed: cargo not found."
    exit
  fi
}

check_java_env() {
  if [ -z "$(which java)" ]; then
    echo "Java env check failed: java not found."
    exit
  fi
  if [ -z "$(which mvn)" ]; then
    echo "Java env check failed: mvn not found."
    exit
  fi
}

install_graphmap() {
  global graphmap_parse
  local cwd=$(pwd)

  cd ${scriptdir}
  if [ ! -d graph-map ]; then
    git clone https://github.com/frankmcsherry/graph-map
  fi
  if [ ! -d graph-map ]; then
    echo "Failed to clone graph-map"
    exit
  fi
  cd graph-map
  if [ ! -f ./target/release/parse ]; then
    cargo build --release
  fi
  if [ ! -f ./target/release/parse ]; then
    echo "Failed to build graph-map for 'parse'."
    exit
  fi
  graphmap_parse=$(realpath ./target/release/parse)
  cd ${cwd}
}

install_terashuf() {
  global terashuf
  local cwd=$(pwd)

  cd ${scriptdir}
  if [ ! -d terashuf ]; then
    git clone --depth=1 https://github.com/alexandres/terashuf
  fi
  if [ ! -d terashuf ]; then
    echo "Failed to clone terashuf"
    exit
  fi
  cd terashuf
  if [ ! -f terashuf ]; then
    make
  fi
  if [ ! -f terashuf ]; then
    echo "Failed to make terashuf"
    exit
  fi
  terashuf=$(realpath ./terashuf)
  cd ${cwd}
}

randomize() {
  if [ -z "$1" ]; then
    echo "Graph file not given"
    exit
  fi
  local name=$(realpath $1)
  install_terashuf
  ${terashuf} < $1 > $1.rand
}

edges2graphmap() {
  if [ -z "$1" ]; then
    echo "Graph file not given"
    exit
  fi
  local name=$(realpath $1)

  check_rust_env
  install_graphmap
  ${graphmap_parse} ${name} ${name} sort dedup
}

install_webgraphz() {
  local cwd=$(pwd)

  cd ${scriptdir}
  if [ ! -d webgraphz ]; then
    git clone https://github.com/zzxx-husky/webgraphz
  fi
  if [ ! -d webgraphz ]; then
    echo "Failed to clone webgraphz"
    exit
  fi
  webgraphz_convert=$(realpath ./webgraphz/scripts/decompress)
  cd ${cwd}
}

webgraph2edges() {
  if [ -z "$1" ]; then
    echo "Graph file not given"
    exit
  fi
  local name=$(dirname $(realpath $1.graph))/$1

  check_java_env
  install_webgraphz
  ${webgraphz_convert} graph-file ${name} output-file ${name}.edges
}

download_livejournal() {
  local dir=$1
  if [ -z ${dir} ]; then
    dir=$(pwd)
  fi
  dir=$(realpath ${dir})
  cd ${dir}

  local url=https://snap.stanford.edu/data/soc-LiveJournal1.txt.gz
  local name=$(name_from_url ${url})
  xwget ${url}
  decompress ${name}
}

download_twitter() {
  local dir=$1
  if [ -z ${dir} ]; then
    dir=$(pwd)
  fi
  dir=$(realpath ${dir})
  cd ${dir}

  local url=http://data.law.di.unimi.it/webdata/twitter-2010/twitter-2010
  local name=$(name_from_url ${url})
  for ext in graph properties md5sums; do
    local urlext=${url}.${ext}
    xwget ${urlext}
  done
  if [ ! -z $(which md5sums) ]; then
    md5sums -c ${name}.md5sums
  fi
}

download_webuk_2007_05() {
  local dir=$1
  if [ -z ${dir} ]; then
    dir=$(pwd)
  fi
  dir=$(realpath ${dir})
  cd ${dir}

  local url=http://data.law.di.unimi.it/webdata/uk-2007-05/uk-2007-05
  local name=$(name_from_url ${url})
  for ext in graph properties md5sums; do
    local urlext=${url}.${ext}
    xwget ${urlext}
  done
  if [ ! -z $(which md5sums) ]; then
    md5sums -c ${name}.md5sums
  fi
}

if [ ${action} = "download" ]; then
  echo "Select the indices of graphs to download:"
  echo 
  for ((i=0, sz=${#graphs[@]}; i < sz; i++)) do
    echo "[$((${i} + 1))] ${graphs[${i}]}"
  done
  echo 
  echo -n "which ones? "
  read input
  echo

  read -ra NUMBERS <<< ${input}
  num_graphs=${#graphs[@]}
  for n in ${NUMBERS[@]}; do
    if [[ "${n}" =~ ^[0-9]+$ ]] && [ ${n} -ge 1 ] && [ ${n} -le ${num_graphs} ]; then
      n=$((${n}-1))
      graphs_to_download="${graphs_to_download} ${graphs[${n}]}"
    else
      echo "Invalid index: "${n}
      exit
    fi
  done

  for n in ${graphs_to_download[@]}; do
    download_${n}
  done
elif [ ${action} = "edges2graphmap" ]; then
  edges2graphmap $2
elif [ ${action} = "webgraph2edges" ]; then
  webgraph2edges $2 
elif [ ${action} = "randomize" ]; then
  randomize $2
else 
  echo "Unknown action: ${action}"
fi
