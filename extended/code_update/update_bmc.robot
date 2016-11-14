*** Settings ***
Documentation     Trigger code update to a target BMC.
...               Execution Method :
...               python -m robot -v OPENBMC_HOST:<hostname>
...               -v FILE_PATH:<path/*all.tar>  update_bmc.robot
...
...               Code update method BMC using REST
...               Update work flow sequence:
...                 - User input BMC File existence check
...                 - Ping Test and REST authentication
...                 - Set Host Power host setting Policy to RESTORE_LAST_STATE
...                   On reboot this policy would ensure the BMC comes
...                   online and stays at HOST_POWERED_OFF state.
...                 - Issue poweroff
...                 - Prepare for Update
...                 - Wait for BMC to come online clean
...                 - Wait for BMC_READY state
...                 - Apply preserve BMC Network setting
...                 - SCP image to BMC
...                 - Activate the flash image
...                 - Warm Reset BMC to activate code
...                 - Wait for BMC to come online time out 30 minutes
...                 - Version check post update

Resource          code_update_utils.robot
Resource          ../../lib/boot/boot_resource_master.robot

*** Variables ***

${FILE_PATH}      ${EMPTY}

*** Test cases ***

Initiate Code update BMC
    [Documentation]    BMC code update process initiation

    Check If File Exist    ${FILE_PATH}
    System Readiness Test
    ${status}=   Run Keyword and Return Status
    ...   Validate BMC Version   before

    Run Keyword if  '${status}' == '${False}'
    ...     Pass Execution   Same Driver version installed

    Initiate Power Off
    Set Policy Setting   RESTORE_LAST_STATE
    Prepare For Update

    # Wait time is increased temporary to 10 mins due
    # to openbmc/openbmc#673
    Check If BMC is Up    10 min   10 sec

    @{states}=   Create List   BMC_READY   HOST_POWERED_OFF
    Wait Until Keyword Succeeds
    ...    10 min   10 sec   Verify BMC State   ${states}

    Preserve BMC Network Setting
    SCP Tar Image File to BMC   ${FILE_PATH}

    Activate BMC flash image

    Run Keyword And Ignore Error    Trigger Warm Reset
    # Warm reset adds 3 seconds delay before forcing reboot
    # To minimize race conditions, we wait for 7 seconds
    Sleep  7s
    ${session_active}=   Check If warmReset is Initiated
    Run Keyword If   '${session_active}' == '${True}'
    ...    Trigger Warm Reset via Reboot

    Check If BMC is Up    30 min   10 sec
    Sleep  1 min
    Validate BMC Version
    Wait Until Keyword Succeeds
    ...    10 min   10 sec   Verify BMC State   BMC_READY

Test BMC CPU Mem Performance at Ready State
    Check BMC CPU Performance
    Check BMC Mem Performance
