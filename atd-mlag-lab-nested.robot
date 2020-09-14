*** Settings ***
Documentation     ATD Lab MLAG: Control and Data Plane Testing
Suite Setup       Connect To Switches
Suite Teardown    Clear All Connections
Library           AristaLibrary
Library           AristaLibrary.Expect
Library           Collections
Library           Process

Variables     /opt/atd/topologies/${TOPOLOGY}/topo_build.yml

*** Variables ***
${TRANSPORT}    http
${LEAF3}    None
${LEAF4}    None
${HOST1}    None
${HOST2_ENDIP}    172.16.112.202
${SPINE1}    None
${SPINE2}    None
${USERNAME}    arista
${PASSWORD}    arista
*** Test Cases ***
Verify MLAG state on Leaf3 is Inactive
    [Documentation]    Verify MLAG state on Leaf3 is Inactive
    Change To Switch   1
    ${mlag}=     Get Command Output    switch_id=1   cmd=show mlag
    ${mlagstate}=    Get From Dictionary    ${mlag[1]}    negStatus
    Should Not Be Equal     ${mlagstate}    connected

Verify Host1 can reach Host2
    [Documentation]    Host2 should be reachable from Host1
    Change To Switch   3
    ${output}=  Enable   ping ${HOST2_ENDIP}
    ${result}=   Get From Dictionary    ${output[0]}    result
    Log     ${result}
    ${match}    ${group1}=  Should Match Regexp    ${result['messages'][0]}    (\\d+)% packet loss
    Should Be Equal As Integers     ${group1}   0   msg="Packets lost percent is not 0%!!!"

Extend configuration on Leaf4
    Change To Switch    2
    @{cmds}=    Create List
    ...    interface port-channel 10
    ...    switchport mode trunk
    ...    interface ethernet 1
    ...    switchport mode trunk
    ...    channel-group 10 mode active
    ...    !
    ...    vlan 4094
    ...    trunk group MLAGPEER
    ...    interface port-channel 10
    ...    switchport trunk group MLAGPEER
    ...    exit
    ...    no spanning-tree vlan-id 4094
    ...    interface vlan 4094
    ...    description MLAG PEER LINK
    ...    ip address 172.16.34.2/30
    ...    !
    ...    mlag
    ...    domain-id MLAG34
    ...    local-interface vlan 4094
    ...    peer-address 172.16.34.1
    ...    peer-link port-channel 10
    ...    !
    ...    interface port-channel 4
    ...    switchport access vlan 12
    ...    mlag 4
    ...    interface ethernet 4
    ...    channel-group 4 mode active
    ...    interface ethernet5
    ...    shutdown
    Configure   ${cmds}
    Sleep   30s

Verify MLAG state on Leaf3 is Connected
    [Documentation]    Verify MLAG state on Leaf3 is Connected
    Change To Switch   1
    ${mlag}=     Get Command Output    switch_id=1   cmd=show mlag
    ${mlagstate}=    Get From Dictionary    ${mlag[1]}    negStatus
    Should Be Equal     ${mlagstate}    connected

Host1 to Host2 Data Plane Reachability
    [Documentation]    Host1 should be able to reach Host2
    Change To Switch   3
    ${output}=  Enable   ping ${HOST2_ENDIP}
    ${result}=   Get From Dictionary    ${output[0]}    result
    Log     ${result}
    ${match}    ${group1}=  Should Match Regexp    ${result['messages'][0]}    (\\d+)% packet loss
    Should Be Equal As Integers     ${group1}   0   msg="Packets lost percent not zero!!!"

Disable Po4 link on Leaf3
    Change To Switch    1
    @{cmds}=    Create List
    ...    interface ethernet4
    ...    shutdown
    Configure   ${cmds}
    Sleep   10s

Host1 to Host2 Data Plane Reachability over Leaf4
    [Documentation]    Host1 should be able to reach Host2
    Change To Switch   3
    ${output}=  Enable   ping ${HOST2_ENDIP}
    ${result}=   Get From Dictionary    ${output[0]}    result
    Log     ${result}
    ${match}    ${group1}=  Should Match Regexp    ${result['messages'][0]}    (\\d+)% packet loss
    Should Be Equal As Integers     ${group1}   0   msg="Packets lost percent not zero!!!"

*** Keywords ***
Connect To Switches
    [Documentation]    Establish connection to a switch which gets used by test cases.
    Log To Console     Load MLAG lab. NOTE: This might take some time!
    Run Process    /usr/bin/python    /usr/local/bin/ConfigureTopology.py    -t   Datacenter   -l    mlag      stdout=/tmp/stdout.tmp    stderr=/tmp/stderr.tmp
    Sleep    50s

    FOR    ${veos_struct}     IN      @{NODES}
        ${veos_name}=   Get Dictionary Keys  ${veos_struct}
        ${veos_data}=   Get From Dictionary    ${veos_struct}    ${veos_name[0]}
        ${veos_ip}=   Get From Dictionary    ${veos_data}    ip_addr
        ${LEAF3}=   Set Variable If   '${veos_name[0]}'=="leaf3"     ${veos_ip}
        Exit For Loop If    "${LEAF3}" != 'None'
    END
    Log    ${LEAF3}

    FOR    ${veos_struct}     IN      @{NODES}
        ${veos_name}=   Get Dictionary Keys  ${veos_struct}
        ${veos_data}=   Get From Dictionary    ${veos_struct}    ${veos_name[0]}
        ${veos_ip}=   Get From Dictionary    ${veos_data}    ip_addr
        ${LEAF4}=   Set Variable If   '${veos_name[0]}'=="leaf4"     ${veos_ip}
        Exit For Loop If    "${LEAF4}" != 'None'
    END
    Log    ${LEAF4}

    FOR    ${veos_struct}     IN      @{NODES}
        ${veos_name}=   Get Dictionary Keys  ${veos_struct}
        ${veos_data}=   Get From Dictionary    ${veos_struct}    ${veos_name[0]}
        ${veos_ip}=   Get From Dictionary    ${veos_data}    ip_addr
        ${HOST1}=   Set Variable If   '${veos_name[0]}'=="host1"     ${veos_ip}
        Exit For Loop If    "${HOST1}" != 'None'
    END
    Log    ${HOST1}

    Connect To    host=${LEAF3}    transport=${TRANSPORT}    username=${USERNAME}    password=${PASSWORD}    port=80
    Connect To    host=${LEAF4}    transport=${TRANSPORT}    username=${USERNAME}    password=${PASSWORD}    port=80
    Connect To    host=${HOST1}    transport=${TRANSPORT}    username=${USERNAME}    password=${PASSWORD}    port=80
