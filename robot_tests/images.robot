*** Settings ***
Library    lib/Fakeroot.py
Library    lib/CommManager.py    mode=Process
Library    ../.venv/lib/python3.10/site-packages/robot/libraries/String.py
Test Timeout    45m

*** Test Cases ***

#==================================
# Tests for QEMU AMD64 Jammy images
#==================================
Build Image amd64/qemu/jammy
    [Tags]    amd64    qemu    debootstrap    jammy    systemd
    Test Systemd Image    amd64/qemu/jammy

#==================================
# Tests for QEMU AMD64 EBcL images
#==================================
Build Image amd64/qemu/ebcl/systemd
    [Tags]    amd64    qemu    berrymill    kiwi    ebcl    systemd
    Test Systemd Image    amd64/qemu/ebcl/systemd

Build Image amd64/qemu/ebcl/crinit
    [Tags]    amd64    qemu    debootstrap    ebcl    crinit
    Test Crinit Image    amd64/qemu/ebcl/crinit

Build Image amd64/qemu/ebcl-server/crinit
    [Tags]    amd64    qemu    debootstrap    ebcl    crinit    server
    Test Crinit Image    amd64/qemu/ebcl-server/crinit

Build Image amd64/qemu/ebcl-server/systemd
    [Tags]    amd64    qemu    debootstrap    ebcl    systemd    server
    Test Systemd Image    amd64/qemu/ebcl-server/systemd

#==================================
# Tests for QEMU ARM64 Jammy images
#==================================
Build Image arm64/qemu/jammy
    [Tags]    arm64    qemu    debootstrap    jammy    systemd
    Test Systemd Image    arm64/qemu/jammy

#==================================
# Tests for QEMU ARM64 EBcL images
#==================================
Build Image arm64/qemu/ebcl/systemd
    [Tags]    arm64    qemu    debootstrap    ebcl    systemd
    Test Systemd Image    arm64/qemu/ebcl/systemd

Build Image arm64/qemu/ebcl/crinit
    [Tags]    arm64    qemu    crinit    ebcl    crinit
    Test Crinit Image    arm64/qemu/ebcl/crinit

#======================
# Tests for RDB2 images
#======================
Build Image arm64/nxp/rdb2/systemd
    [Tags]    arm64    rdb2    hardware    debootstrap    ebcl    systemd
    Test Hardware Image    arm64/nxp/rdb2/systemd

Build Image arm64/nxp/rdb2/crinit
    [Tags]    arm64    rdb2    hardware    debootstrap    ebcl    crinit
    Test Hardware Image    arm64/nxp/rdb2/crinit

Build Image arm64/nxp/rdb2/network
    [Tags]    arm64    rdb2    hardware    debootstrap    ebcl    crinit    network
    Test Hardware Image    arm64/nxp/rdb2/network

#================================
# Tests for Raspberry Pi 4 images
#================================
Build Image arm64/raspberry/pi4/crinit
    [Tags]    arm64    pi4    hardware    debootstrap    ebcl    crinit    network
    Test Hardware Image    arm64/raspberry/pi4/crinit

Build Image arm64/raspberry/pi4/systemd
    [Tags]    arm64    pi4    hardware    debootstrap    ebcl    systemd
    Test Hardware Image    arm64/raspberry/pi4/systemd

Build Image arm64/nxp/rdb2/systemd/server
    [Tags]    arm64    pi4    hardware    debootstrap    ebcl    systemd    server
    Test Hardware Image    arm64/nxp/rdb2/systemd/server

#========================
# Tests for appdev images
#========================
Build Image amd64/appdev/qemu/crinit
    [Tags]    amd64    qemu    debootstrap    crinit    ebcl    appdev
    Test Crinit Image    amd64/appdev/qemu/crinit

Build Image amd64/appdev/qemu/systemd
    [Tags]    amd64    qemu    debootstrap    systemd    ebcl    appdev
    Test Systemd Image    amd64/appdev/qemu/systemd

Build Image arm64/appdev/qemu/crinit
    [Tags]    arm64    qemu    debootstrap    crinit    ebcl    appdev
    Test Crinit Image    arm64/appdev/qemu/crinit

Build Image arm64/appdev/qemu/systemd
    [Tags]    arm64    qemu    debootstrap    systemd    ebcl    appdev
    Test Systemd Image    arm64/appdev/qemu/systemd

Build Image arm64/appdev/pi4/crinit
    [Tags]    arm64    pi4    hardware    debootstrap    ebcl    crinit    appdev
    Test Hardware Image    arm64/appdev/pi4/crinit

Build Image arm64/appdev/pi4/systemd
    [Tags]    arm64    pi4    hardware    debootstrap    ebcl    systemd    appdev
    Test Hardware Image    arm64/appdev/pi4/systemd

Build Image arm64/appdev/rdb2/crinit
    [Tags]    arm64    rdb2    hardware    debootstrap    ebcl    systemd    appdev
    Test Hardware Image    arm64/appdev/rdb2/crinit

Build Image arm64/appdev/rdb2/systemd
    [Tags]    arm64    rdb2    hardware    debootstrap    ebcl    crinit    appdev
    Test Hardware Image    arm64/appdev/rdb2/systemd


#==========================================
# Tests for images using local built kernel
#==========================================
Build Image arm64/nxp/rdb2/kernel_src
    [Tags]    arm64    rdb2    hardware    debootstrap    ebcl    systemd    kernel_src
    [Timeout]    90m
    Test Hardware Image    arm64/nxp/rdb2/kernel_src

#==================================
# Tests for old format images
#==================================
Build Image example-old-images/qemu/berrymill
    [Tags]    amd64    qemu    berrymill    kiwi    ebcl    old
    [Timeout]    60m
    ${path}=    Set Variable    example-old-images/qemu/berrymill
    # ---------------
    # Build the image
    # ---------------
    ${full_path}=    Set Variable    /workspace/images/example-old-images/qemu/berrymill
    ${results_folder}=    Evaluate    $full_path + '/build'
    Connect
    # Remove old build artefacts - build from scratch
    Run Make    ${full_path}    clean    2m 
    # Build the image
    ${result}=    Execute    source /build/venv/bin/activate; cd ${full_path}; make image
    # Check for Embdgen log
    Should Contain    ${result}    Image was written to
    Sleep    1s
    # Check that image file exists
    ${file_info}=    Execute    cd ${results_folder}; file root.qcow2
    Should Not Contain    ${file_info}    No such file
    # Clear the output queue
    Clear Lines    
    Sleep    1s
    # -------------
    # Run the image
    # -------------
    Test That Make Does Not Rebuild    ${path}
    Run Image    ${path}
    Send Message    \ncrinit-ctl poweroff
    Sleep    20s
    Disconnect

*** Keywords ***
Run Make
    [Arguments]    ${path}    ${target}    ${max_time}=2h
    [Timeout]    ${max_time}
    ${result}=    Execute    source /build/venv/bin/activate; cd ${path}; make ${target}
    RETURN    ${result}

Build Image
    [Arguments]    ${path}    ${image}=image.raw    ${max_time}=1h
    [Timeout]    ${max_time}
    ${full_path}=    Evaluate    '/workspace/images/' + $path
    ${results_folder}=    Evaluate    $full_path + '/build'
    
    # Remove old build artefacts - build from scratch
    Run Make    ${full_path}    clean    2m 

    # Build the initrd
    ${result}=    Execute    source /build/venv/bin/activate; cd ${full_path}; make initrd
    # Check for boot generator log
    Should Contain    ${result}    Image was written to

    Sleep    1s

    # Build the kernel
    ${result}=    Execute    source /build/venv/bin/activate; cd ${full_path}; make boot
    # Check for boot generator log
    Should Contain    ${result}    Results were written to

    Sleep    1s

    # Build the image
    ${result}=    Execute    source /build/venv/bin/activate; cd ${full_path}; make image
    # Check for Embdgen log
    Should Contain    ${result}    Writing image to

    Sleep    1s
    
    # Check that image file exists
    ${file_info}=    Execute    cd ${results_folder}; file ${image}
    Should Not Contain    ${file_info}    No such file
    
    # Clear the output queue
    Clear Lines    
    Sleep    1s

Test That Make Does Not Rebuild
    [Arguments]    ${path}
    [Timeout]    1m
    ${full_path}=    Evaluate    '/workspace/images/' + $path
    ${output}=    Run Make    ${full_path}    image
    Should Contain    ${output}    Nothing to be done for 'image'

Run Image
    [Arguments]    ${path}
    [Timeout]    5m
    ${full_path}=    Evaluate    '/workspace/images/' + $path
    Send Message    source /build/venv/bin/activate; cd ${full_path}; make qemu
    ${success}=    Login To Vm
    Should Be True    ${success}

Check For Startup Errors
    [Timeout]    2m
    # Filter known log containing the error search word.
    ${kernel_logs}=    Execute    dmesg
    ${kernel_logs}=    Replace String    ${kernel_logs}    Correctable Errors collector initialized    \
    Should Not Contain    ${kernel_logs}    error    ignore_case=${True}

Check For Startup Fails
    [Timeout]    2m
    ${kernel_logs}=    Execute    dmesg
    Should Not Contain    ${kernel_logs}    failed    ignore_case=${True}

Check For Crinit Task Issues
    [Timeout]    2m
    ${crinit}=    Execute    crinit-ctl list
    Should Not Contain    ${crinit}    failed    ignore_case=${True}
    Should Not Contain    ${crinit}    wait    ignore_case=${True}

Check For Systemd Unit Issues
    [Timeout]    2m
    ${systemd}=    Execute    systemctl list-units --no-pager
    Should Not Contain    ${systemd}    failed    ignore_case=${True}

Shutdown Systemd Image
    [Timeout]    2m
    Send Message    \nsystemctl poweroff
    Wait For Line Containing    System Power Off
    Sleep    1s

Test Systemd Image
    [Arguments]    ${path}    ${image}=image.raw
    Connect
    Build Image    ${path}    ${image}
    Test That Make Does Not Rebuild    ${path}
    Run Image    ${path}
    Check For Startup Errors
    # TODO: Check For Systemd Unit Issues
    Shutdown Systemd Image
    Disconnect

Shutdown Crinit Image
    [Timeout]    2m
    Send Message    \ncrinit-ctl poweroff
    Wait For Line Containing    Power down
    Sleep    1s

Test Crinit Image
    [Arguments]    ${path}    ${image}=image.raw
    Connect
    Build Image    ${path}    ${image}
    Test That Make Does Not Rebuild    ${path}
    Run Image    ${path}
    Check For Startup Errors
    Check For Startup Fails
    Check For Crinit Task Issues
    Shutdown Crinit Image
    Disconnect

Test Hardware Image
    [Arguments]    ${path}    ${image}=image.raw
    Connect
    Build Image    ${path}    ${image}
    Test That Make Does Not Rebuild    ${path}
