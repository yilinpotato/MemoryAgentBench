source ~/.bashrc

if ! command -v conda >/dev/null 2>&1; then
    echo "conda command not found. Please install/initialize conda first."
    exit 1
fi

eval "$(conda shell.bash hook)"
conda activate MABench

export PYTHONUNBUFFERED=1
export OMP_NUM_THREADS=1
root=$(pwd)

if [ -f "$root/.env" ]; then
    while IFS= read -r env_line || [ -n "$env_line" ]; do
        if [ -z "$env_line" ] || [[ "$env_line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        if [[ "$env_line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            env_key="${env_line%%=*}"
            env_value="${env_line#*=}"
            env_key="$(printf '%s' "$env_key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            env_value="$(printf '%s' "$env_value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            if [[ "$env_value" =~ ^\".*\"$ ]] || [[ "$env_value" =~ ^\'.*\'$ ]]; then
                env_value="${env_value:1:-1}"
            fi
            export "$env_key=$env_value"
        else
            echo "Skip malformed .env line: $env_line"
        fi
    done < "$root/.env"
fi


file_name=rag_agents_chunksize.txt
line_no=${LINE_NO:-}
config_list=${root}/bash_files/configs/${file_name}
max_test_queries=${MAX_TEST_QUERIES_ABLATION:-10}
force_arg=""
if [ "${FORCE_RUN:-0}" = "1" ]; then
    force_arg="--force"
fi

if [ ! -f "$config_list" ]; then
    echo "Config list not found: $config_list"
    exit 1
fi

if [ -n "$line_no" ]; then
    lines_to_run="$line_no"
else
    lines_to_run=$(seq 1 "$(wc -l < "$config_list")")
fi

for line in $lines_to_run
do
        cfg=$(sed -n "${line}p" "$config_list")

        if [ -z "$cfg" ] || [[ "$cfg" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        agent_config=$(echo "$cfg" | awk '{print $1}')
        dataset_config=$(echo "$cfg" | awk '{print $2}')
        chunk_size_ablation=$(echo "$cfg" | awk '{print $3}')

        if [ -z "$agent_config" ] || [ -z "$dataset_config" ] || [ -z "$chunk_size_ablation" ]; then
            echo "Skip malformed line ${line}: $cfg"
            continue
        fi

        agent_config_path="configs/agent_conf/RAG_Agents/gpt-4o-mini/${agent_config}"
        dataset_config_path="configs/data_conf/${dataset_config}"

        if [ ! -f "$agent_config_path" ]; then
            echo "Agent config not found: $agent_config_path"
            continue
        fi
        if [ ! -f "$dataset_config_path" ]; then
            echo "Dataset config not found: $dataset_config_path"
            continue
        fi


        echo ................Start........... 
        CUDA_VISIBLE_DEVICES=7 python main.py \
                                    --agent_config        "$agent_config_path" \
                                    --dataset_config      "$dataset_config_path" \
                                    --chunk_size_ablation "$chunk_size_ablation" \
                                    --max_test_queries_ablation "$max_test_queries" \
                                    $force_arg
        run_status=$?
        echo ................End...........

        if [ "$run_status" -ne 0 ]; then
            echo "Run failed on line ${line} with exit code ${run_status}. Stop remaining runs."
            exit "$run_status"
        fi

done

# bash bash_files/sh/run_memagent_rag_agents_chunksize.sh   
