function emu --description 'Launch Android emulator (RAM/cores/GPU come from the AVD config)'
    # Usage: emu            -> launches api36 (default)
    #        emu Pixel_7_Pro -> launches a named AVD
    #        emu -l          -> list available AVDs
    #        emu api36 -wipe-data -> extra flags pass straight through
    #
    # RAM (4G), cores (4) and GPU (host) are set in ~/.android/avd/<name>.avd/config.ini
    # NOT passed as CLI flags -- CLI overrides invalidate the Quick Boot snapshot and force
    # a slow cold boot. Keeping them in config = fast snapshot boots.
    set -l avd dev35
    if test (count $argv) -gt 0
        switch $argv[1]
            case -l -list --list
                emulator -list-avds
                return
            case '*'
                set avd $argv[1]
        end
    end
    emulator -avd $avd -no-boot-anim $argv[2..-1]
end
