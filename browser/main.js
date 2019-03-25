/////////////////////////////////////////////////////////////////////////////////////////
// main.js
// the framework for communicating with skynet server and displaying console in browser
// The actual communication routines (websockets) are in skynet.js
/////////////////////////////////////////////////////////////////////////////////////////

var skynet = Skynet(); // object to hold base skynet function calls e.g. send_message

// skynet message event_type:
var PPC_CONNECTED = "ppc_connected";
var PPC_DISCONNECTED = "ppc_disconnected";
var PPC_STATUS = "ppc_status";
var PPC_MSG = "ppc_msg";
var PPC_IDLE = "ppc_idle";
var PPC_RESERVED = "ppc_reserved";
var PPC_WAITING = "ppc_waiting";
var PPC_STARTING = "ppc_starting";          // 'run' command has been sent to PPC
var PPC_RUNNING = "ppc_running";
var PPC_SPLIT = "ppc_split";    // 'split' response from PPC
var PPC_NOSPLIT = "ppc_nosplit";    // 'nosplit' response from PPC
var PPC_COMPLETED = "ppc_completed";
var PPC_EXIT = "ppc_exit";
var SKYNET_WARNING = "skynet_warning";
var SKYNET_MSG = "skynet_msg";

var flow_node_names; // array of node names in order of hosts_area elements
var flow_node_index = {}; // mapping from node_name to index 0..flow_host_count-1
var flow_status; // array. holds current status value for each node
var flow_row_status = PPC_IDLE; // current default 'status' for flow row (change triggers new row)

function on_load() 
{
    skynet.init();
    // debug - test button create
    //do_connect('foo','bah');
}

//---------------------------------------------------------------------------------------
//------------------- HANDLE USER INPUT                              --------------------
//---------------------------------------------------------------------------------------

// triggered on button next to user text input field, or enter key
function user_text()
{
    // get text input by user
    var user_input = document.getElementById('user_input').value;
    // write text to browser status area
    status_text('status_text_user', user_input);
    // send the user text as a message to skynet server
    skynet.skynet_send_msg('skynet', 'user_input', user_input);
    user_menu_hide();
}

// call 'user_text()' to execute the command chosen from the menu dropdown
function user_menu_command(el)
{
    console.log('user_menu_command');
    // set text input as if by user
    document.getElementById('user_input').value = el.innerHTML;
    //alert(el.innerHTML);
    user_text();
}

// display the drop_down menu below the user command input box
function user_menu_show()
{
    //alert('show_user_menu');
    console.log('show_user_menu');
    var user_menu = document.getElementById('user_input_menu');
    user_menu.setAttribute('class','user_input_menu_show');
}

// hide the drop_down menu below the user command input box
function user_menu_hide()
{
    //alert('hide_user_menu');
    var user_menu = document.getElementById('user_input_menu');
    user_menu.setAttribute('class','user_input_menu_hide');
}

// set the logging/flow window to display the flow diagram
function user_status_flow()
{
    document.getElementById('status_text').style.display = "none";
    document.getElementById('status_flow').style.display = "block";
}

function user_status_console()
{
    document.getElementById('status_flow').style.display = "none";
    document.getElementById('status_text').style.display = "block";
}

function user_status_clear()
{
    status_area_clear();
    status_flow_init();
}

function timestamp()
{
    var d = new Date();
    var h = ("0"+d.getHours()).slice(-2);
    var m = ("0"+d.getMinutes()).slice(-2);
    var s = ("0"+d.getSeconds()).slice(-2);
    var ms = ("000"+d.getMilliseconds()).slice(-3);
    return h+':'+m+':'+s+'.'+ms;
}

//---------------------------------------------------------------------------------------
//------------------- FUNCTIONS FROM USER MENU                       --------------------
//---------------------------------------------------------------------------------------

function user_split(host_name, slot_name)
{
    skynet.skynet_send_msg('skynet', 'user_input', 'skynet split '+host_name+' '+slot_name);
}

function user_kill(host_name, slot_name)
{
    skynet.skynet_send_msg('skynet', 'user_input', 'skynet kill '+host_name+' '+slot_name);
}

function user_disconnect(host_name, slot_name)
{
    skynet.skynet_send_msg('skynet', 'user_input', 'skynet disconnect '+host_name+' '+slot_name);
}

function user_send(host_name, slot_name)
{
    // get text input by user
    var user_input = document.getElementById('user_input').value;
    // write text to browser status area
    status_text('status_text_user', host_name+':'+slot_name+'~ '+user_input);
    skynet.skynet_send_msg('skynet', 'user_input', 'skynet send '+host_name+' '+slot_name+' '+user_input);
}

//---------------------------------------------------------------------------------------
//------------------- FUNCTIONS TRIGGERED BY INCOMING COMMANDS       --------------------
//---------------------------------------------------------------------------------------

// create 'id' for hosts_area element given host_name & slot_name
function make_host_button(host_name, slot_name)
{
    return host_name+':'+slot_name+':button';
}

// make a node_name from host & slot    
function make_nn(host_name, slot_name)
{
    return host_name+':'+slot_name;
}
    
// process PPC_CONNECTED event from skynet server
function do_connect(host_name, slot_name)
{
    /* E.g.
    <div id="skynet:slot7:button" class="host">
    <ul><li id="skynet:slot7" class="ppc_connected"><a href="#">skynet:slot4</a>
        <ul>
          <li><a href="#">Sub Menu 1</a></li>
          <li><a href="#">Sub Menu 2</a></li>
          <li><a href="#">Sub Menu 3</a></li>
        </ul>
        </li>
    </ul>
    </div>
    */
    
    // check to see if host_area element already exists for this node
    var node_name = make_nn(host_name, slot_name);
    
    var node_element = document.getElementById(node_name);
    if (node_element)
    {
            // if it exists, just set its background color to 'connected'
            node_element.setAttribute('class','ppc_connected');
            return;
    }
    
    // an existing host_area button doesn't exist for this node, so create one
    var div = document.createElement('DIV');
    div.setAttribute('id', node_name);
    div.setAttribute('class', 'host');
    var ul1 = document.createElement('UL');
    var li1 = document.createElement('LI');
    li1.setAttribute('id',make_host_button(host_name,slot_name));
    li1.setAttribute('class','ppc_idle');
    var a1 = document.createElement('A');
    a1.setAttribute('href','#');
    var displayname = document.createTextNode(node_name);
    a1.appendChild(displayname);
    var ul2 = document.createElement('UL');
    
    var a2 = document.createElement('A');
    var li2 = document.createElement('LI');
    var menu2 = document.createTextNode('Send Command');
    a2.setAttribute('href','javascript:user_send("'+host_name+'","'+slot_name+'");');
    a2.appendChild(menu2);
    li2.appendChild(a2);
    ul2.appendChild(li2);
    
    var a3 = document.createElement('A');
    var li3 = document.createElement('LI');
    var menu3 = document.createTextNode('menu2');
    a3.setAttribute('href','#');
    a3.appendChild(menu3);
    li3.appendChild(a3);
    ul2.appendChild(li3);
    
    var a4 = document.createElement('A');
    var li4 = document.createElement('LI');
    var menu4 = document.createTextNode('Split');
    a4.setAttribute('href','javascript:user_split("'+host_name+'","'+slot_name+'");');
    a4.appendChild(menu4);
    li4.appendChild(a4);
    ul2.appendChild(li4);
    
    var a5 = document.createElement('A');
    var li5 = document.createElement('LI');
    var menu5 = document.createTextNode('Kill');
    a5.setAttribute('href','javascript:user_kill("'+host_name+'","'+slot_name+'");');
    a5.appendChild(menu5);
    li5.appendChild(a5);
    ul2.appendChild(li5);
    
    var a6 = document.createElement('A');
    var li6 = document.createElement('LI');
    var menu6 = document.createTextNode('Disconnect');
    a6.setAttribute('href','javascript:user_disconnect("'+host_name+'","'+slot_name+'");');
    a6.appendChild(menu6);
    li6.appendChild(a6);
    ul2.appendChild(li6);
    
    li1.appendChild(a1);
    li1.appendChild(ul2);
    ul1.appendChild(li1);
    div.appendChild(ul1);
    
    document.getElementById('hosts_area').appendChild(div);
    
    // reset the status area
    status_area_clear();
    status_flow_init(); // this will update the top row with the correct number of nodes


}

// process PPC_DISCONNECTED event from skynet server
function do_disconnect(host_name, slot_name)
{
    console.log('do_disconnect');
    var li = document.getElementById(make_host_button(host_name,slot_name));
    if (li)
    {
        li.setAttribute('class','ppc_disconnected');
    }
    else
    {
        //debug
        console.log('Just received a disconnect for unknown node '+host_name+':'+slot_name);
    }
}

// process PPC_MSG event from skynet server
function do_ppc_msg(host_name, slot_name, msg)
{
    status_text('status_text_ppc', host_name+':'+slot_name+'~ '+msg);
}

function do_ppc_status(host_name, slot_name, status)
{
    switch (status)
    {
        case PPC_WAITING:
            do_ppc_waiting(host_name, slot_name);
            break;
            
        case PPC_RUNNING:
            do_ppc_running(host_name, slot_name);
            break;
            
        case PPC_IDLE:
            do_ppc_idle(host_name, slot_name);
            break;
            
        case PPC_RESERVED:                      // received during refresh
            do_ppc_reserved(host_name, slot_name);
            break;
            
        default:
            status_text('status_text_warning',"Unexpected PPC status: "+
                            host_name+" "+slot_name+ " "+status);
    }
}

// process PPC_WAITING event from skynet server
function do_ppc_waiting(host_name, slot_name)
{
    console.log('do_ppc_waiting');
    var node_name = make_nn(host_name, slot_name);
    var li = document.getElementById(make_host_button(host_name,slot_name));
    if (li)
    {
        li.setAttribute('class','ppc_waiting');
        // update status flow diagram
        status_flow_update(node_name, PPC_WAITING);
    }
    else
    {
        //debug
        console.log('Just received a ppc_waiting status for unknown node '+host_name+':'+slot_name);
    }
}

// process PPC_RUNNING event from skynet server
function do_ppc_running(host_name, slot_name, task_info)
{
    console.log('do_ppc_running',host_name,slot_name,task_info);
    var node_name = make_nn(host_name, slot_name);
    var li = document.getElementById(make_host_button(host_name,slot_name));
    if (li)
    {
        li.setAttribute('class','ppc_running');
        if (task_info)
        {
            do_ppc_msg(host_name, slot_name, "RUNNING "+task_info);
        }
        // update status flow diagram
        status_flow_update(node_name, PPC_RUNNING);
    }
    else
    {
        //debug
        console.log('Just received a ppc_running for unknown node '+host_name+':'+slot_name);
    }
}

// process PPC_SPLIT event from skynet server
function do_ppc_split(host_name, slot_name, split_info)
{
    console.log('do_ppc_split',host_name,slot_name,split_info);
    var node_name = make_nn(host_name, slot_name);
    var li = document.getElementById(make_host_button(host_name,slot_name));
    if (li)
    {
        li.setAttribute('class','ppc_split');
        if (split_info)
        {
            do_ppc_msg(host_name, slot_name, "SPLIT "+split_info);
        }
        // update status flow diagram
        status_flow_update(node_name, PPC_SPLIT);
    }
    else
    {
        //debug
        console.log('Just received a ppc_split for unknown node '+host_name+':'+slot_name);
    }
}

// process PPC_NOSPLIT event from skynet server
function do_ppc_nosplit(host_name, slot_name)
{
    console.log('do_ppc_nosplit',host_name,slot_name);
    var node_name = make_nn(host_name, slot_name);
    var li = document.getElementById(make_host_button(host_name,slot_name));
    if (li)
    {
        li.setAttribute('class','ppc_nosplit');
        do_ppc_msg(host_name, slot_name, "NOSPLIT");
        // update status flow diagram
        status_flow_update(node_name, PPC_NOSPLIT);
    }
    else
    {
        //debug
        console.log('Just received a ppc_nosplit for unknown node '+host_name+':'+slot_name);
    }
}

// process PPC_COMPLETED event from skynet server
// task_info = PROC ORACLE G N WORK_COMPLETED e.g. "kappa 450 12 3 14"
function do_ppc_completed(host_name, slot_name, task_info)
{
    console.log('do_ppc_completed',host_name,slot_name,task_info);
    var node_name = make_nn(host_name, slot_name);
    var li = document.getElementById(make_host_button(host_name,slot_name));
    if (li)
    {
        // note we reset node to 'LOADED' status
        li.setAttribute('class','ppc_waiting');
        do_ppc_msg(host_name, slot_name, "COMPLETED "+task_info)
        // update status flow diagram
        status_flow_update(node_name, PPC_WAITING);
    }
    else
    {
        //debug
        console.log('Just received a ppc_completed for unknown node '+host_name+':'+slot_name);
    }
}

// process PPC_EXIT event from skynet server
function do_ppc_exit(host_name, slot_name)
{
    do_ppc_idle(host_name, slot_name);
}

// process PPC_IDLE event from skynet server
function do_ppc_idle(host_name, slot_name)
{
    console.log('do_ppc_idle');
    var node_name = make_nn(host_name, slot_name);
    var li = document.getElementById(make_host_button(host_name,slot_name));
    if (li)
    {
        // note we reset node to 'IDLE' status
        li.setAttribute('class','ppc_idle');
        // update status flow diagram
        status_flow_update(node_name, PPC_IDLE);
    }
    else
    {
        //debug
        console.log('Just received a ppc_idle for unknown node '+host_name+':'+slot_name);
    }
}

// process PPC_RESERVED event from skynet server
function do_ppc_reserved(host_name, slot_name)
{
    console.log('do_ppc_reserved');
    var node_name = make_nn(host_name, slot_name);
    var li = document.getElementById(make_host_button(host_name,slot_name));
    if (li)
    {
        // note we reset node to 'IDLE' status
        li.setAttribute('class','ppc_reserved');
    }
    else
    {
        //debug
        console.log('Just received a ppc_reserved for unknown node '+host_name+':'+slot_name);
    }
}

//---------------------------------------------------------------------------------------
//------------------- WRITE TO STATUS AREA IN LOG FORMAT             --------------------
// i.e. scrolling lines of text, latest at the bottom
//---------------------------------------------------------------------------------------

function status_area_clear()
{
    // clear existing status console rows
    var myNode = document.getElementById('status_text');
    while (myNode.firstChild) {
        myNode.removeChild(myNode.firstChild);
    }
        // clear existing status flow rows
    myNode = document.getElementById('status_flow');
    while (myNode.firstChild) {
        myNode.removeChild(myNode.firstChild);
    }

}

// write text to browser status area
function status_text(status_class, text)
{
    // add this text as a new 'user' line for the status area
    var new_line = document.createElement('LI');
    new_line.setAttribute('class',status_class);
    var line_text = document.createTextNode(timestamp()+' '+text);
    new_line.appendChild(line_text);
    document.getElementById('status_text').appendChild(new_line);
    var status_div = document.getElementById('status_area');
    status_div.scrollTop = status_div.scrollHeight;
}


//---------------------------------------------------------------------------------------
//------------------- DRAW THE STATUS FLOW DIAGRAM                   --------------------
//---------------------------------------------------------------------------------------

// initialize the status flow
// i.e. reset vars and draw headings
function status_flow_init()
{
    flow_node_names = new Array(); // cache the node names found while iterating the hosts_area children
    flow_status = new Array(); // will hold current status for each node
    flow_node_index = {};
    flow_row_status = PPC_IDLE;
    var flow_node_count = 0;
    
    // iterate the nodes
    var host_elements = document.getElementById('hosts_area').children;
    for (var i=0; i<host_elements.length; i++)
    {
        if (host_elements[i].className == "host")
        {
            // for each 'host' element, increment count, cache node_name, and set flow_status
            var node_name = host_elements[i].id;
            flow_node_names[flow_node_count] = node_name;
            flow_node_index[node_name] = flow_node_count; // create cross-reference for node_name -> index
            //console.log('flow init flow_node_index[',node_name,'] =',flow_node_index[node_name]);
            flow_status[flow_node_count] = PPC_IDLE; // default initial status PPC_IDLE
            flow_node_count++;
        }
    }
    
    // add a TH element to "status_flow" for each host
    var tr = document.createElement('TR');
    // first add blank TH above timestamp column
    var blank_th = document.createElement('TH');
    var blank_th_text = document.createTextNode(' ');
    blank_th.appendChild(blank_th_text);
    tr.appendChild(blank_th);
    // now add a column for each node
    for (var i=0; i<flow_node_names.length; i++)
    {
        var th = document.createElement('TH');
        th.setAttribute('title',flow_node_names[i]);
        var th_text = document.createTextNode(i+1); // count from 1...
        th.appendChild(th_text);
        tr.appendChild(th);
    }
    document.getElementById('status_flow').appendChild(tr);
}

// return true if all nodes are in PPC_WAITING state
function status_flow_all_waiting()
{
    for (var i=0; i<flow_node_names.length; i++)
    {
        if (flow_status[i] != PPC_WAITING) return false;
    }
    return true;
}

// Update the current row in the status flow, moving to new row if necessary
function status_flow_update(node_name, status)
{
    console.log('status_flow_update',node_name,status);
    console.log('current row is',flow_row_status);
    var node_index = flow_node_index[node_name];
    if (flow_row_status != status)
    {
        status_flow_flush();
        flow_row_status = status;
    }
    console.log('update setting flow_status[',node_index,'] to',status);
    flow_status[node_index] = status;
    // final flush if all nodes are waiting
    if (status_flow_all_waiting())
    {
        status_flow_flush();
    }
}

// some node status has changed, so it's time to output the current row
function status_flow_flush()
{
    // add a TH element to "status_flow" for each host
    var tr = document.createElement('TR');
    // add timestamp to start of row
    var td = document.createElement('TD');
    td.innerHTML = timestamp();
    tr.appendChild(td);
    // add column for status of each node
    for (var i=0; i<flow_node_names.length; i++)
    {
        var td = document.createElement('TD');
        td.className = flow_status[i];
        //debug
        var status_element = document.createElement('SPAN');
        //console.log('flushing row flow_status[',i,'] is',flow_status[i]);
        switch (flow_status[i])
        {
            case PPC_IDLE:
                status_element.innerHTML = ':';
                break;
                
            case PPC_CONNECTED:
                status_element.innerHTML = 'C';
                break;
                
            case PPC_WAITING:
                status_element.innerHTML = '|';
                break;
                
            case PPC_RUNNING:
                status_element.innerHTML = 'R';
                break;
                
            case PPC_SPLIT:
                status_element.innerHTML = '*';
                break;
                
            case PPC_NOSPLIT:
                status_element.innerHTML = 'X';
                break;
                
            default:
                status_element.innerHTML = '?';
        }
        td.appendChild(status_element);
        tr.appendChild(td);
    }
    document.getElementById('status_flow').appendChild(tr);
    
    // auto-scroll status_area to bottom of content
    var status_div = document.getElementById('status_area');
    status_div.scrollTop = status_div.scrollHeight;

}

//---------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------
//------------------- HANDLE THE SKYNET EVENTS, e.g. shouts          --------------------
//---------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------

var zone_id = 'skynet';

// Here is where we receive 'shout' messages from the server, which
// have been mapped to javascript custom events by skynet.js

// listen for JavaScript events from Skynet socket
window.addEventListener("skynet_event", skynet_event, false);

function skynet_event(event)
{
    //console.log("main.js skynet_event", event.detail);
    process_shout(event.detail, false);
}

// Process shout messages from the server.
// Either called from skynet_event above, or recursively called when
// an incoming shout contains a list of messages.
// 'refresh' is a boolean that says 'act on all messages' rather then
// be picky about is this message from this client or other clients.
function process_shout(msg, refresh)
{
    // ignore events not directed at this 'zone' of the browser window
    // main zone is zone 'skynet'
    if (msg.zone == zone_id)
    {
        console.log("main.js shout received for event_type", msg.event_type, "(refresh=",refresh,")");
        switch (msg.event_type)
        {
            case PPC_CONNECTED:
                console.log("main.js got PPC_CONNECTED message ",msg.host_name, msg.slot_name);
                do_connect(msg.host_name, msg.slot_name);
                break;
            case PPC_DISCONNECTED:
                console.log("main.js got PPC_DISCONNECTED message ",msg.host_name, msg.slot_name);
                do_disconnect(msg.host_name, msg.slot_name);
                break;
            case PPC_STATUS:
                console.log("main.js got PPC_STATUS message ",msg.host_name, msg.slot_name, msg.data);
                do_ppc_status(msg.host_name, msg.slot_name, msg.data);
                break;
            case PPC_COMPLETED:
                console.log("main.js got PPC_COMPLETED message ",msg.host_name, msg.slot_name);
                do_ppc_completed(msg.host_name, msg.slot_name, msg.data);
                break;
            case PPC_RUNNING:
                console.log("main.js got PPC_RUNNING message ",msg.host_name, msg.slot_name, msg.data);
                do_ppc_running(msg.host_name, msg.slot_name, msg.data);
                break;
            case PPC_SPLIT:
                console.log("main.js got PPC_SPLIT message ",msg.host_name, msg.slot_name, msg.data);
                do_ppc_split(msg.host_name, msg.slot_name, msg.data);
                break;
            case PPC_NOSPLIT:
                console.log("main.js got PPC_NOSPLIT message ",msg.host_name, msg.slot_name);
                do_ppc_nosplit(msg.host_name, msg.slot_name);
                break;
            case PPC_EXIT:
                console.log("main.js got PPC_EXIT message ",msg.host_name, msg.slot_name);
                do_ppc_exit(msg.host_name, msg.slot_name);
                break;
            case PPC_MSG:
                console.log("main.js got PPC_MSG message ",msg.host_name, msg.slot_name);
                do_ppc_msg(msg.host_name, msg.slot_name, msg.data);
                break;
            case SKYNET_WARNING:
                console.log("main.js got SKYNET_WARNING message ",msg.data);
                status_text('status_text_warning', "Skynet warning: "+msg.data);
                break;
            default:
                console.log("main.js process_shout unknown msg:", msg);
                document.getElementById('status_area').innerHTML += '<br/>From server: ' + JSON.stringify(msg);
        }
    }
}

