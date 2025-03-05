#!/bin/bash

src_yml=$1
yml=$2
env=${3:-"env"}

echo "x-shared-env: &shared-env" > $yml
while IFS= read -r line; do
    if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        yq eval ".x-shared-env.$key = \"\${$key:-$value}\"" $yml -i
    else
        continue
    fi
done < <(grep -vE "^(#.*|\s*)$" "$env") 

for item1 in $(yq eval ". | to_entries[] | .key" $src_yml); do
    if [ $item1 == "services" ]; then
        yq eval ".$item1 = {}" $yml -i    
        for item2 in $(yq eval ".$item1 | to_entries[] | .key" $src_yml); do
            yq eval ".$item1.$item2 = {}" $yml -i  
            for item3 in $(yq eval ".$item1.$item2 | to_entries[] | .key" $src_yml); do              
                if [ $item3 == "env_file" ] || [ $item3 == "environment" ]; then
                    yq eval ".$item1.$item2.environment = {\"<<\":\"*shared-env\"}" $yml -i
                    if [ $(yq eval ".$item1.$item2 | has(\"environment\")" $src_yml) == true ]; then
                        if [ $(yq eval ".$item1.$item2.environment  | type" $src_yml) == "!!seq" ]; then
                            for kvs in $(yq eval ".$item1.$item2.environment[]" $src_yml); do
                                key=${kvs%=*}
                                value=${kvs#*=}
                                yq eval ".$item1.$item2.environment.$key = \"$value\"" $yml -i
                            done
                        else
                            yq eval ".$item1.$item2.environment += load(\"$src_yml\").$item1.$item2.environment" $yml -i
                        fi
                    fi
                    continue                    
                fi
                yq eval ".$item1.$item2.$item3 = load(\"$src_yml\").$item1.$item2.$item3" $yml -i 
            done
        done
    else  
        yq eval ".$item1 = load(\"$src_yml\").$item1" $yml -i      
    fi    
done

sed -i "s/!!merge <<: '\*shared-env'/<<: *shared-env/g" $yml