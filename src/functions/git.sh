#Wrapper for the git function that allows for 
# -s or --salesforce to be given as params to 
# git init, causing the regular init to run,
# plus some setup for salesforce projects
git() { 
    ###### ARGUMENT PARSING SECTION ######

    #ensure OPTIND reset, also done at end
    OPTIND=1
    salesforce_flag=false
    help_flag=false
    
    temp_params_short_to_examine=()
    params_final=()

    for arg do
        first_char=$(echo ${arg} | cut -c1-1)
        first_two_chars=$(echo ${arg} | cut -c1-2)

        if [[ "$first_two_chars" == "--" ]]; then
            #LONG ARG
            # Acknowlege and strip salesforce flag
            # else: Add the long arg to final args to pass through
            case $arg in
                --salesforce ) salesforce_flag=true ;; 
                --help       ) help_flag=true; params_final+=("$arg") ;;
                *            ) params_final+=("$arg") ;;
            esac
        else
            #ANY NON-LONG ARG
            # Check if is a short arg
            # else: add the arg to final args to pass through
            if [[ "$first_char" == "-" ]] ; then
                #SHORT ARG[s]
                # Acknowledge sf flag, strip any "s" out of short arg string
                # Add the final string to final args to pass through, if 
                #   not reduced to a single dash
                while getopts ":sh " opt "${arg}"; do
                    case $opt in
                        s  ) salesforce_flag=true ;;
                        h  ) help_flag=true ;;
                        \? )                      ;;
                    esac
                done
                OPTIND=1
                strip_s_arg=("${arg//s/}")
                if [[ "$strip_s_arg" != "-" ]]; then
                    params_final+=("$strip_s_arg")
                fi
            else
                if [[ "$arg" == "help" ]]; then
                    help_flag=true
                fi
                params_final+=("$arg")
            fi
        fi
    done

    OPTIND=1



    ###### GIT INIT OVERRIDE SECTION ######
    
    core_command=${params_final[0]}
    #If:
    #   - the core command is init, 
    #   - the salesforce_flag was set
    #   - the help flag was NOT set,
    #THEN do the special handling
    #else: call git with the params array
    #
    #If the help flag is set, regular git would not execute anything other than
    # showing the man page, so neither will we
    if  [[ 
            $core_command == "init" && 
            $salesforce_flag == "true" && 
            $help_flag != "true" 
        ]]; then 
        echo "Setting up temp dir" 
        workingdir=$(pwd) 
        tempdir=$(mktemp -dt gitinitsftmp) 
        (
            cd $tempdir && 
            echo "Doing git init" && 
            #call git init, passing through any parameters that were supplied
            command git "${params_final[@] --quiet}" && 
            echo "Retrieving .gitignore" && 
            curl -#o  .gitignore https://gist.github.com/Oblongmana/7130387/raw/.gitignore-sf && 
            echo "Creating apex-scripts dir" && 
            mkdir -p apex-scripts && 
            echo "Creating src/classes dir" && 
            mkdir -p src/classes && 
            echo "Creating README.md" && 
            touch README.md && 
            echo "Moving from temp dir to $workingdir" && 
            cp -R $tempdir/. $workingdir && 
            echo "Initialized Salesforce git repository in $workingdir"
        ) 
        echo "Cleaning out temp dir"  
        rm -rf $tempdir 
    else 
        #if: there are no params, call plain git with no params, 
        #else: provide params
        if [[ ${#params_final[@]} == "0" ]]; then
            command git
        else
            command git "${params_final[@]}"
            #If:
            # - the help flag is set somewhere in the args; 
            # AND
            # - The "core_command" [first word following the git command] is one of:
            # |- init
            # |- -h
            # |- --help
            # |- help
            # 
            #Then we append some helpful info on the extensions we've added
            if [[ 
                    $help_flag == "true" &&
                    (
                        $core_command == "init" ||
                        $core_command == "-h" ||
                        $core_command == "--help" ||
                        $core_command == "help"
                    )
                ]]; then
                echo
                echo "git-enhance usage note: "
                echo "    git init can take the custom [-s | --salesforce] flag to initialise with a "
                echo "    standard .gitignore, empty README.md, and file structure for salesforce "
                echo "    projects. Requires an internet connection."
                echo
            fi
        fi
    fi
}