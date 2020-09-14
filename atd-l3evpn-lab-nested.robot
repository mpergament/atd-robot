*** Settings ***
Documentation     ATD Lab L3 EVPN: Control and Data Plane Testing
Suite Setup       Connect To Switches
Suite Teardown    Clear All Connections
Library           AristaLibrary
Library           AristaLibrary.Expect
Library           Collections
Library           Process

*** Variables ***
${TRANSPORT}    http
${LEAF1}    None
${LEAF3}    None
${HOST1}    None
${SPINE1}    None
${SPINE2}    None
${USERNAME}    arista
${PASSWORD}    arista
${SPINE1_LOOPBACK}    None
${SPINE2_LOOPBACK}    None
${LEAF3_LOOPBACK}    172.16.0.5/32
*** Test Cases ***
Get Spine1 Loopback IP 
    [Documentation]    Get Loopback IP for futher tests
    ${interfaces}=     Get Command Output    switch_id=4   cmd=show ip interface brief
    ${result}=    Get Dictionary Items    ${interfaces}
    ${ifs}=    Get From Dictionary    ${result[1]}    interfaces
    ${lo0}=    Get From Dictionary    ${ifs}    Loopback0
    ${addrstruct}=    Get From Dictionary    ${lo0}    interfaceAddress
    ${addrmask}=    Get From Dictionary    ${addrstruct}    ipAddr
    ${address}=    Get From Dictionary    ${addrmask}    address
    ${maskLen}=    Get From Dictionary    ${addrmask}    maskLen
    Set Global Variable      ${SPINE1_LOOPBACK}    ${address}/${maskLen}
    Set Global Variable      ${SPINE1_LOIP}    ${address}
    Log     ${SPINE1_LOOPBACK}

Get Spine2 Loopback IP 
    [Documentation]    Get Loopback IP for futher tests
    ${interfaces}=     Get Command Output    switch_id=5   cmd=show ip interface brief
    ${result}=    Get Dictionary Items    ${interfaces}
    ${ifs}=    Get From Dictionary    ${result[1]}    interfaces
    ${lo0}=    Get From Dictionary    ${ifs}    Loopback0
    ${addrstruct}=    Get From Dictionary    ${lo0}    interfaceAddress
    ${addrmask}=    Get From Dictionary    ${addrstruct}    ipAddr
    ${address}=    Get From Dictionary    ${addrmask}    address
    ${maskLen}=    Get From Dictionary    ${addrmask}    maskLen
    Set Global Variable      ${SPINE2_LOOPBACK}    ${address}/${maskLen}
    Set Global Variable      ${SPINE2_LOIP}    ${address}
    Log     ${SPINE2_LOOPBACK}

BGP Sessions State on Leaf1
    [Documentation]    Check if BGP peerings are Established on Leaf1
    ${bgp}=     Get Command Output    switch_id=1   cmd=show ip bgp summary
    ${result}=    Get Dictionary Items    ${bgp}
    ${vrfs}=    Get From Dictionary    ${result[1]}    vrfs
    ${default_vrf}=     Get From Dictionary    ${vrfs}    default
    ${peers}=   Get From Dictionary     ${default_vrf}     peers
    FOR    ${peer}     IN      @{peers}
       Log     ${peer}
       ${peer_dict}=   Get From Dictionary     ${peers}     ${peer}
       ${state}=   Get From Dictionary     ${peer_dict}     peerState
       Should Be Equal     ${state}    Established
    END

Spine's Loopbacks Learned via BGP on Leaf1
    [Documentation]    Check if spine's loopbacks are known via BGP
    Get Command Output    switch_id=1   cmd=show ip bgp
    Expect    vrfs default bgpRouteEntries    to contain    ${SPINE1_LOOPBACK}
    Expect    vrfs default bgpRouteEntries    to contain   ${SPINE2_LOOPBACK}

Leaf3 Loopback Absence
    [Documentation]    Check if leaf3 loopback is not learned via BGP
    Get Command Output    switch_id=1   cmd=show ip bgp
    Expect    vrfs default bgpRouteEntries    to not contain    ${LEAF3_LOOPBACK}

Leaf1 Control Plane Snapshot
    [Documentation]    Capture the current state of BGP RIB
    ${bgp_state}=   Get Command Output  switch_id=1   cmd=show ip bgp
    Log     ${bgp_state}

Spine1 Data Plane Reachability from Leaf1 
    [Documentation]    Spine1 loopback should be reachable from leaf1
    Change To Switch   1
    ${output}=  Enable   ping ${SPINE1_LOIP}
    ${result}=   Get From Dictionary    ${output[0]}    result
    Log     ${result}
    ${match}    ${group1}=  Should Match Regexp    ${result['messages'][0]}    (\\d+)% packet loss
    Should Be Equal As Integers     ${group1}   0   msg="Packets lost percent not zero!!!"

Extend configuration on Leaf3
    Change To Switch    2
    @{cmds}=    Create List
    ...   vrf instance vrf1
    ...   !
    ...   ip routing vrf vrf1
    ...   !
    ...   vlan 12,34,2003
    ...   !
    ...   interface Port-Channel5
    ...   description HOST2
    ...   switchport access vlan 2003
    ...   no shutdown
    ...   !
    ...   interface Ethernet1
    ...   shutdown
    ...   !
    ...   interface Ethernet2
    ...   description SPINE1
    ...   no switchport
    ...   ip address 172.16.200.10/30
    ...   !
    ...   interface Ethernet3
    ...   description SPINE2
    ...   no switchport
    ...   ip address 172.16.200.26/30
    ...   !
    ...   interface Ethernet4
    ...   shutdown
    ...   !
    ...   interface Vlan2003
    ...   mtu 9000
    ...   no autostate
    ...   vrf vrf1
    ...   ip address virtual 172.16.116.1/24
    ...   !
    ...   interface Loopback901
    ...   vrf vrf1
    ...   ip address 200.200.200.2/32
    ...   !
    ...   interface Ethernet5
    ...   description HOST2
    ...   channel-group 5 mode active
    ...   no shutdown
    ...   !
    ...   interface Loopback0
    ...   ip address 172.16.0.5/32
    ...   !
    ...   interface Loopback1
    ...   ip address 3.3.3.3/32
    ...   !
    ...   interface Vxlan1
    ...   vxlan source-interface Loopback1
    ...   vxlan udp-port 4789
    ...   vxlan vrf vrf1 vni 1001
    ...   !
    ...   router bgp 65103
    ...   router-id 172.16.0.5
    ...   maximum-paths 2 ecmp 2
    ...   neighbor SPINE peer group
    ...   neighbor SPINE remote-as 65001
    ...   neighbor SPINE bfd
    ...   neighbor SPINE maximum-routes 12000
    ...   neighbor 172.16.200.9 peer group SPINE
    ...   neighbor 172.16.200.25 peer group SPINE
    ...   redistribute connected
    ...   neighbor SPINE-EVPN-TRANSIT peer group
    ...   neighbor SPINE-EVPN-TRANSIT update-source Loopback0
    ...   neighbor SPINE-EVPN-TRANSIT ebgp-multihop
    ...   neighbor SPINE-EVPN-TRANSIT send-community
    ...   neighbor SPINE-EVPN-TRANSIT remote-as 65001
    ...   neighbor SPINE-EVPN-TRANSIT maximum-routes 0
    ...   neighbor 172.16.0.1 peer group SPINE-EVPN-TRANSIT
    ...   neighbor 172.16.0.2 peer group SPINE-EVPN-TRANSIT
    ...   !
    ...   address-family evpn
    ...   neighbor SPINE-EVPN-TRANSIT activate
    ...   !
    ...   address-family ipv4
    ...   no neighbor SPINE-EVPN-TRANSIT activate
    ...   !
    ...   vrf vrf1
    ...   rd 3.3.3.3:1001
    ...   route-target import evpn 1:1001
    ...   route-target export evpn 1:1001
    ...   redistribute connected
    ...   redistribute static
    Configure   ${cmds}
    Sleep   30s

Host1 to Host2 Data Plane Reachability
    [Documentation]    Host1 should be able to reach Host2
    Change To Switch   3
    ${output}=  Enable   ping 172.16.116.100
    ${result}=   Get From Dictionary    ${output[0]}    result
    Log     ${result}
    ${match}    ${group1}=  Should Match Regexp    ${result['messages'][0]}    (\\d+)% packet loss
    Should Be Equal As Integers     ${group1}   0   msg="Packets lost percent not zero!!!"

*** Keywords ***
Connect To Switches
    [Documentation]    Establish connection to a switch which gets used by test cases.
    Log To Console     Load L3 EVPN lab. NOTE: This might take some time!
    Run Process    /usr/bin/python    /usr/local/bin/ConfigureTopology.py    -t   Datacenter   -l    l3evpn      stdout=/tmp/stdout.tmp    stderr=/tmp/stderr.tmp
    Sleep    50s
    FOR    ${veos_struct}     IN      @{NODES}
        ${veos_name}=   Get Dictionary Keys  ${veos_struct}
        ${veos_data}=   Get From Dictionary    ${veos_struct}    ${veos_name[0]}
        ${veos_ip}=   Get From Dictionary    ${veos_data}    ip_addr
        ${LEAF1}=   Set Variable If   '${veos_name[0]}'=="leaf1"     ${veos_ip} 
        Exit For Loop If    "${LEAF1}" != 'None'
    END
    Log    ${LEAF1}

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
        ${HOST1}=   Set Variable If   '${veos_name[0]}'=="host1"     ${veos_ip} 
        Exit For Loop If    "${HOST1}" != 'None'
    END
    Log    ${HOST1}

    FOR    ${veos_struct}     IN      @{NODES}
        ${veos_name}=   Get Dictionary Keys  ${veos_struct}
        ${veos_data}=   Get From Dictionary    ${veos_struct}    ${veos_name[0]}
        ${veos_ip}=   Get From Dictionary    ${veos_data}    ip_addr
        ${SPINE1}=   Set Variable If   '${veos_name[0]}'=="spine1"     ${veos_ip} 
        Exit For Loop If    "${SPINE1}" != 'None'
    END
    Log    ${SPINE1}

    FOR    ${veos_struct}     IN      @{NODES}
        ${veos_name}=   Get Dictionary Keys  ${veos_struct}
        ${veos_data}=   Get From Dictionary    ${veos_struct}    ${veos_name[0]}
        ${veos_ip}=   Get From Dictionary    ${veos_data}    ip_addr
        ${SPINE2}=   Set Variable If   '${veos_name[0]}'=="spine2"     ${veos_ip} 
        Exit For Loop If    "${SPINE2}" != 'None'
    END
    Log    ${SPINE2}

    Connect To    host=${LEAF1}    transport=${TRANSPORT}    username=${USERNAME}    password=${PASSWORD}    port=80 
    Connect To    host=${LEAF3}    transport=${TRANSPORT}    username=${USERNAME}    password=${PASSWORD}    port=80
    Connect To    host=${HOST1}    transport=${TRANSPORT}    username=${USERNAME}    password=${PASSWORD}    port=80
    Connect To    host=${SPINE1}    transport=${TRANSPORT}    username=${USERNAME}    password=${PASSWORD}    port=80 
    Connect To    host=${SPINE2}    transport=${TRANSPORT}    username=${USERNAME}    password=${PASSWORD}    port=80 
