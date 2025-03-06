#!/bin/bash

src_yml=$1
yml=$2
name=${3:-"env-file"}

declare -A env_file_name_set
declare -A env_file_path_set
for service in $(yq ".services | to_entries[] | .key" $src_yml); do
    for env_file in $(yq ".services.$service.env_file[]" $src_yml); do
        if [ -n "${env_file_name_set[$env_file]}" ]; then
            continue
        fi
        env_file_name_set[$env_file]="$name${#env_file_name_set[@]}"
        if [[ $env_file != /* ]]; then
            env_file_path_set[$env_file]=$(realpath $(dirname $src_yml)/$env_file)
        else
            env_file_path_set[$env_file]=$env_file
        fi        
    done
done

echo "" > $yml

for env_file in ${!env_file_name_set[@]}; do
    env_file_name=${env_file_name_set[$env_file]}
    env_file_path=${env_file_path_set[$env_file]}
    yq ".x-$env_file_name anchor = \"$env_file_name\"" $yml -i
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            yq ".x-$env_file_name.$key = \"\${$key:-$value}\"" $yml -i
        fi
    done < <(grep -vE "^(#.*|\s*)$" "$env_file_path") 
done

for item1 in $(yq ". | to_entries[] | .key" $src_yml); do
    if [ $item1 == "services" ]; then 
        for item2 in $(yq ".$item1 | to_entries[] | .key" $src_yml); do
            env_file_length=$(yq ".$item1.$item2.env_file | length" $src_yml)
            if [ $env_file_length -gt 0 ]; then
                for item3 in $(yq ".$item1.$item2 | to_entries[] | .key" $src_yml); do
                    if [ $item3 == "env_file" ]; then
                        if [ $env_file_length -eq 1 ]; then
                            env_file=$(yq ".$item1.$item2.$item3[0]" $src_yml)
                            yq ".$item1.$item2.environment.<< alias = \"${env_file_name_set[$env_file]}\"" $yml -i
                        else
                            for i in $(seq 0 $(($env_file_length-1))); do
                                env_file=$(yq ".$item1.$item2.$item3[$i]" $src_yml)
                                yq ".$item1.$item2.environment.<<[$i] alias = \"${env_file_name_set[$env_file]}\"" $yml -i
                            done
                        fi
                        environment_type=$(yq ".$item1.$item2.environment | type" $src_yml)
                        if [ $environment_type == "!!seq" ]; then
                            for kvs in $(yq ".$item1.$item2.environment[]" $src_yml); do
                                if [[ "$kvs" =~ ^([^=]+)=(.*)$ ]]; then
                                    key="${BASH_REMATCH[1]}"
                                    value="${BASH_REMATCH[2]}" 
                                    yq ".$item1.$item2.environment.$key = \"$value\"" $yml -i
                                fi                                
                            done
                        elif [ $environment_type == "!!map" ]; then
                            yq ".$item1.$item2.environment += load(\"$src_yml\").$item1.$item2.environment" $yml -i
                        else
                            continue
                        fi
                    elif [ $item3 == "environment" ]; then
                        continue
                    else
                        yq ".$item1.$item2.$item3 = load(\"$src_yml\").$item1.$item2.$item3" $yml -i                 
                    fi                
                done                
            else
                yq ".$item1.$item2 = load(\"$src_yml\").$item1.$item2" $yml -i
            fi        
        done
    else  
        yq ".$item1 = load(\"$src_yml\").$item1" $yml -i      
    fi    
done

yq "(... | select(tag == \"!!merge\")) tag = \"\"" $yml -i