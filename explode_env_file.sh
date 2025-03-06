#!/bin/bash

src_yml=$1
yml=$2
env=${3:-"shared-env"}

declare -A env_file_set
for service in $(yq ".services | to_entries[] | .key" $src_yml); do
    for env_file in $(yq ".services.$service.env_file[]" $src_yml); do        
        if [[ $env_file != /* ]]; then
            env_file="$(realpath $(dirname $src_yml)/$env_file)"
        fi
        env_file_set[$env_file]=$env_file
    done
done

echo "" > $yml
if [ ${#env_file_set[@]} -gt 0 ]; then
    yq ".x-$env anchor = \"$env\"" $yml -i
    for env_file in ${env_file_set[@]}; do
        while IFS= read -r line; do
            if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
                key="${BASH_REMATCH[1]}"
                value="${BASH_REMATCH[2]}"
                yq ".x-$env.$key = \"\${$key:-$value}\"" $yml -i
            fi
        done < <(grep -vE "^(#.*|\s*)$" "$env_file") 
    done
fi

for item1 in $(yq ". | to_entries[] | .key" $src_yml); do
    if [ $item1 == "services" ]; then 
        for item2 in $(yq ".$item1 | to_entries[] | .key" $src_yml); do
            if [ $(yq ".$item1.$item2 | has(\"env_file\")" $src_yml) == "true" ]; then
                for item3 in $(yq ".$item1.$item2 | to_entries[] | .key" $src_yml); do
                    if [ $item3 == "env_file" ]; then
                        yq ".$item1.$item2.environment.<< alias = \"$env\"" $yml -i
                        case $(yq ".$item1.$item2.environment | type" $src_yml) in
                            !!seq)
                                for kvs in $(yq ".$item1.$item2.environment[]" $src_yml); do
                                    if [[ "$kvs" =~ ^([^=]+)=(.*)$ ]]; then
                                        key="${BASH_REMATCH[1]}"
                                        value="${BASH_REMATCH[2]}" 
                                        yq ".$item1.$item2.environment.$key = \"$value\"" $yml -i
                                    fi                                
                                done
                                ;;
                            !!map)
                                yq ".$item1.$item2.environment += load(\"$src_yml\").$item1.$item2.environment" $yml -i
                                ;;
                            *)
                                continue
                                ;;
                        esac
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