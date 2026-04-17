source ~/.bashrc

if ! command -v conda >/dev/null 2>&1; then
    echo "conda command not found. Please install/initialize conda first."
    exit 1
fi

# Ensure 'conda activate' works in non-interactive script execution.
eval "$(conda shell.bash hook)"
conda activate MABench

export PYTHONUNBUFFERED=1
export OMP_NUM_THREADS=1
root=$(pwd)

if [ -f "$root/.env" ]; then
    while IFS= read -r env_line || [ -n "$env_line" ]; do
        # Skip comments and empty lines.
        if [ -z "$env_line" ] || [[ "$env_line" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        # Only accept KEY=VALUE lines to avoid executing stray text as commands.
        if [[ "$env_line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            env_key="${env_line%%=*}"
            env_value="${env_line#*=}"

            # Trim surrounding whitespace around key/value.
            env_key="$(printf '%s' "$env_key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            env_value="$(printf '%s' "$env_value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

            # Remove optional surrounding quotes in value.
            if [[ "$env_value" =~ ^\".*\"$ ]] || [[ "$env_value" =~ ^\'.*\'$ ]]; then
                env_value="${env_value:1:-1}"
            fi
            export "$env_key=$env_value"
        else
            echo "Skip malformed .env line: $env_line"
        fi
    done < "$root/.env"
fi


file_name=rag_agents.txt
model_dir=${MODEL_DIR:-gpt-4o-mini}
line_no=${LINE_NO:-}
export LLM_MODEL_OVERRIDE=${LLM_MODEL_OVERRIDE:-${LLM_MODEL:-}}
config_list=${root}/bash_files/configs/${file_name}
max_test_queries=${MAX_TEST_QUERIES_ABLATION:-10}

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

    # Skip empty lines and comments.
    if [ -z "$cfg" ] || [[ "$cfg" =~ ^[[:space:]]*# ]]; then
        continue
    fi

    agent_config=$(echo "$cfg" | awk '{print $1}')
    dataset_config=$(echo "$cfg" | awk '{print $2}')

    if [ -z "$agent_config" ] || [ -z "$dataset_config" ]; then
        echo "Skip malformed line ${line}: $cfg"
        continue
    fi

    agent_config_path="configs/agent_conf/RAG_Agents/${model_dir}/${agent_config}"
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
    CUDA_VISIBLE_DEVICES=6 python main.py \
        --agent_config "$agent_config_path" \
        --dataset_config "$dataset_config_path" \
        --max_test_queries_ablation "$max_test_queries"
    run_status=$?
    echo ................End...........

    if [ "$run_status" -ne 0 ]; then
        echo "Run failed on line ${line} with exit code ${run_status}. Stop remaining runs."
        exit "$run_status"
    fi
done

# bash bash_files/sh/run_memagent_rag_agents.sh   
