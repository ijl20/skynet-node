//****************************************************************
//     SKYNET SERVER
//****************************************************************

// This is the main control program for the Skynet network of path processors
//
// Each path processor connects to this control server via a TCP/IP socket
//
// One or more browsers also connect to this control server, both to 'get' the default page
// and connect via a websocket

// using node.js websockets

var VERSION = 1.06;
// 1.06 initial port to new machine
// 1.05 as imported from carrier
//

// port number for node web server and websocket handler
var SKYNET_BROWSER_PORT = 10082;
var SKYNET_PPC_PORT = 10083;

var SKYNET_DOCROOT = '/home/ijl20/src/prolog/skynet-node/browser';

// PPC Commands
var OK = "ok";
var PPC_CMD_CONNECT = "ppc connect";
var PPC_CMD_SPLIT = "ppc split";
var PPC_CMD_KILL = "ppc kill";
var PPC_CMD_SHUTDOWN = "ppc shutdown";

// PPC_STATUS
var PPC_CONNECTED = "ppc_connected";        // socket connection to PPC is active
var PPC_DISCONNECTED = "ppc_disconnected";  // socket connection to PPC lost
var PPC_IDLE = "ppc_idle";                  // PPC started but no child program running
var PPC_WAITING = "ppc_waiting";            // PPC has 'kappa' child program WAITING but waiting
var PPC_STARTING = "ppc_starting";          // 'run' command has been sent to PPC
var PPC_RUNNING = "ppc_running";            // PPC 'kappa' child has reported it's running
var PPC_SPLITTING = "ppc_splitting";        // 'split' command has been sent to PPC
var PPC_SPLIT = "ppc_split";                // 'split' response received from PPC
var PPC_NOSPLIT = "ppc_nosplit";            // 'nosplit' response received from PPC
var PPC_COMPLETED = "ppc_completed";        // PPC 'kappa' child has reported completion
var PPC_RESERVED = "ppc_reserved";          // A 'split' command has been sent to some other PPC
                                            // and this PPC has been reserved for work allocation
var PPC_EXIT = "ppc_exit";                  // PPC child program has exitted

// PPC MESSAGES
var PPC_MSG = "ppc_msg";                    // event type for general message to browser
var PPC_STATUS = "ppc_status";              // event type for messages to browser
var SKYNET = "skynet";
var LOADED = "loaded";
var RUNNING = "running";
var SPLIT = "split";
var NOSPLIT = "nosplit";
var COMPLETED = "completed";
var EXIT = "exit";

// BROWSER EVENTS
var SKYNET_WARNING = "skynet_warning";
var SKYNET_MSG = "skynet_msg";

// *****************************************************************
// kappa count of idle machines that will trigger a SPLIT
// *****************************************************************

var vars = {}; // object 'dictionary' to hold string vars
vars['KAPPA'] = 3; // 0 means no splitting

// *****************************************************************
// *****************************************************************
// global to hold hosts status
// e.g. ppc_status['carrier.csi.cam.ac.uk:slot_1'] = {
//    socket: s,
//    connected: true,
//    status: idle | waiting | running  }

function NodeStatus()
{
    var ppc_status = {};

    var running = new Array();  // FIFO queue of running PPC's
                                // each entry is { node_name, time }
                                // where time is in milliseconds since 1970

    // return full status object for node
    this.get = function (node_name) {
                    return ppc_status[node_name];
    }

    // return names of all connected nodes
    this.all = function () {
                    //console.log('NodeStatus.all for',ppc_status);
                    var node_list = new Array();
                    for (var k in ppc_status)
                    {
                        if (ppc_status[k].connected = true)
                        {
                            node_list.push(k);
                        }
                    }
                    //console.log('NodeStatus.all returning',node_list);
                    return node_list;
    }

    // create/overwrite entry for a new node
    this.add = function (node_name, node_status) {
                    console.log('NodeStatus adding',node_name);
                    ppc_status[node_name] = node_status;
    }

    // return node connected status
    this.connected = function (node_name) {
                    //console.log('NodeStatus.connected',node_name);
                    return ppc_status[node_name].connected;
    }

    // set node connected = true
    this.connect = function (node_name) {
                    if (typeof(node_name) == "undefined" | !node_name)
                    {
                        console_log('Unknown host connected');
                        return;
                    }
                    ppc_status[node_name].connected = true;
    }

    // set node connected = false
    this.disconnect = function (node_name) {
                    if (typeof(node_name) == "undefined" | !node_name)
                    {
                        console_log('Unknown host disconnected');
                        return;
                    }

                    ppc_status[node_name].connected = false;
                    this.set_status(node_name, PPC_DISCONNECTED);
    }

    // return node current status
    this.status = function (node_name) {
                    return ppc_status[node_name].status;
    }

    // set node current status
    this.set_status = function (node_name, new_status) {
                    if (typeof(node_name) == "undefined" | !node_name) return;
                    console.log('---- Skynet set_status',node_name,new_status);
                    var prev_status = ppc_status[node_name].status;
                    // handle race condition of NOSPLIT arriving after COMPLETED
                    if (prev_status == PPC_WAITING && new_status == PPC_NOSPLIT)
                    {
                        // just ignore a NOSPLIT status after a WAITING
                        return;
                    }
                    // set new status
                    ppc_status[node_name].status = new_status;

                    // update the 'running' array if this node no longer running
                    if (prev_status == PPC_RUNNING && new_status != PPC_RUNNING)
                    {
                        // ppc is no longer running, so taint queue entry (set t=0)
                        for (var i=0; i<running.length; i++)
                        {
                            if (running[i].node_name == node_name)
                            {
                                running[i].time = 0;
                            }
                        }
                    }

                    // check to see if we should issue a SPLIT if enough nodes are idle
                    if (prev_status != PPC_WAITING && new_status == PPC_WAITING)
                    {
                        console.log('---- Skynet current WAITING ppcs # is:', this.count(PPC_WAITING));
                        // see if action is needed for KAPPA technique
                        //check_kappa(); // moved this to when we get 'completed' message from ppc
                    }

                    // if state change is to RUNNING,
                    // add this node to the 'running' array (at the end, i.e. as it's newest)
                    if (prev_status != PPC_RUNNING && new_status == PPC_RUNNING)
                    {
                        // we have a new RUNNING ppc, so add to end of queue
                        var t = (new Date()).getTime(); // timestamp in milliseconds since 1970...
                        console.log('Adding',node_name,'to running FIFO at time',t);
                        running.push({ node_name: node_name, time: t });
                        console.log('Length of running FIFO is',running.length);
                        console.log('running[0] is',running[0].node_name);
                    }

    }

    // find G ppc's with status PPC_WAITING and set them to PPC_RESERVED
    // Need to be a bit careful with this code - it has to ensure EITHER reserve G ppc's
    // or reserve NONE. Currently it does this by checking there are enough PPC_WAITING first...
    this.reserve = function (G) {
        if (this.count(PPC_WAITING) < G)
        {
            return false; // not enough waiting ppc's found to reserve...
        }
        // reserved_count keeps track of how many ppc's we've reserved so far
        var reserved_count = 0;
        for (var node_name in ppc_status)
        {
            if (ppc_status[node_name].status == PPC_WAITING)
            {
                console_log('reserving '+node_name);
                ppc_status[node_name].status = PPC_RESERVED;
                reserved_count++;
                if (reserved_count == G)
                {
                    break;
                }
            }
        }
        return true;
    }

    // Un-reserve ppc's previously reserved for a split allocation
    // this is probably because the split was rejected for some reason
    // e.g. the splittable ppc completed anyway or no ppc was found suitable for
    // splitting.
    this.unreserve = function (reserved_count) {
        console_log('unreserve('+reserved_count+')');
        var reset_count = 0;
        for (var node_name in ppc_status)
        {
            if (ppc_status[node_name].status == PPC_RESERVED)
            {
                console_log('unreserve '+node_name);
                this.set_status(node_name, PPC_WAITING);
                reset_count++;
                if (reset_count == reserved_count)
                {
                    break;
                }
            }
        }
    }

    this.reserve_reset = function () {
        console_log('reserve_reset()');
        var reset_count = 0;
        for (var node_name in ppc_status)
        {
            if (ppc_status[node_name].status == PPC_RESERVED)
            {
                console_log('unreserve '+node_name);
                reset_count++;
                this.set_status(node_name, PPC_WAITING);
            }
        }
        console_log('reserve_reset '+reset_count+' ppcs');
    }

    // return count of connected nodes with a given status
    this.count = function (status) {
        var c = 0;
        for (var k in ppc_status)
        {
            if (ppc_status[k].status == status)
            {
                c++;
            }
        }
        return c;
    }

    // return node socket
    this.socket = function (node_name) {
                    return ppc_status[node_name].socket;
    }

    // return longest running ppc
    this.oldest = function() {
        var node_name = '';
        while (running.length > 0)
        {
            node = running.shift(); // running is array with oldest at front
            if (node.time)
            {
                node_name = node.node_name;
                break;
            }
        }
        console.log('Oldest running is',node_name, '. Running FIFO length now',running.length);
        return node_name;
    }
}

// check whether we should send a SPLIT or not
function check_kappa()
{
    var waiting_count = ppc.count(PPC_WAITING);
    if (vars['KAPPA'] && waiting_count >= vars['KAPPA'])
    {
        console_log('check_kappa found '+waiting_count+' waiting ppcs so splitting');
        return true;
    } else {
        console_log('check_kappa found only '+waiting_count+' waiting ppcs so NOT splitting');
    }
    return false;
}

// choose a PPC to SPLIT and send 'split' command
function split_ppc()
{
    var node_name = ppc.oldest();
    if (!node_name)
    {
        console.log('split_ppc: No running ppc to split');
        return;
    }
    // set status of KAPPA ppc's to PPC_RESERVED
    if (!ppc.reserve(vars['KAPPA']))
    {
        console_log('split_ppc error : could not reserve enough ppcs');
        return;
    }
    console.log('split_ppc splitting: ',node_name);
    ppc.set_status(node_name, PPC_SPLITTING);
    ppc_send_msg(node_name,PPC_CMD_SPLIT);
}

// Got NOSPLIT, so choose another PPC to SPLIT and send 'split' command
function nosplit_ppc()
{
    var node_name = ppc.oldest();
    if (!node_name)
    {
        console.log('nosplit_ppc: No running ppc to split');
        return;
    }
    console.log('resplit_ppc splitting: ',node_name);
    ppc.set_status(node_name, PPC_SPLITTING);
    ppc_send_msg(node_name,PPC_CMD_SPLIT);
}

// split_assign called when 'skynet split' message received from PPC
// i.e. a PPC was earlier sent a 'ppc split' message telling it to split
// BFP: run program Proc starting from Oracle O on G machines
// We may have a node_name as first parameter, to be included in work set
// (This is because that ppc was split)
function split_assign(node_name, proc, O, G)
{
    console.log('---- Skynet calling split_assign',node_name, proc,O,G);
    var ppc_found = 0; // number of suitable PPC's found so far
    var ppc_set = new Array(); // object used to accumulate PPC's for this computation
    var all_nodes = ppc.all(); // get list of connected node_names
    var ppc_required = G; // 'G' is the count of path processors required in this workgroup

    // if we have been given a node_name, then definitely include this ppc in the working set
    // Note this is because that ppc has just been split, and currently there is an assumption
    // that a 'split' ppc will always be re-assigned work from its own oracle. This allows an
    // optimization (in future) that the split ppc carries on immediately after being split,
    // because it knows it will be processor '0' in a new workgroup of KAPPA ppc's.
    if (node_name)
    {
        ppc_set.push({ node_name: node_name, rnd: Math.random(), n: ppc_found++ })
        // ppc_found is now 1
    }

    // accumulate the expected KAPPA node_names that are PPC_RESERVED
    // into ppc_set [{node_name, rnd}] where rnd is a random number for sorting
    for (var i=0; i<all_nodes.length; i++)
    {
        var node_name = all_nodes[i];
        if (ppc.connected(node_name) && ppc.status(node_name) == PPC_RESERVED)
        {
            // we will shuffle the set, so add random property to sort on...
            ppc_set.push({ node_name: node_name, rnd: Math.random(), n: ppc_found++ });
        }
        if (ppc_found == ppc_required)
        {
            break; // exit this for loop
        }
    }
    // if we haven't enough PPC's then tell browser and do nothing
    if (ppc_found != ppc_required)
    {
        console.log('---- Skynet not enough WAITING ppcs for bfp',O,G);
        browser_broadcast({ userid: 'skynet',
            zone: 'skynet',
            event_type: SKYNET_WARNING,
            data: 'Not enough path processors for bfp '+O+' '+G
            });
        return;
    }
    // OK it looks like we have enough PPC's so randomize & distribute the job
    // first set status of all ppc's in group to PPC_STARTING
    for (var i=0; i<ppc_set.length; i++)
    {
        ppc.set_status(ppc_set[i].node_name, PPC_STARTING);
    }
    ppc_set.sort(function(a,b) { return a.rnd - b.rnd } );
    for (var N = 0; N < G; N++)
    {
        // send "run <proc> 0 G N" to each path processor
        ppc_send_msg(ppc_set[N].node_name, 'run ' + proc + ' ' + O + ' ' + G + ' ' + ppc_set[N].n + "\n");
    }
}

// *********************************************************************************
// *********************************************************************************
// ***************** Launch code for Server             ****************************
// *********************************************************************************
// *********************************************************************************

var ppc = new NodeStatus();

// require file system module
var fs = require('fs');
// require express web server module
var express = require('express');
// require internal http module
var http = require('http');

var app = express();

var web_server = http.createServer(app);
web_server.listen(SKYNET_BROWSER_PORT);

//require socket.io module
var web_socket = require('socket.io').listen(web_server);

console.log('\n-----\n---- Skynet web server listening on port', SKYNET_BROWSER_PORT);

// WEB SERVER CODE

//app.use(express.bodyParser());

//debug
// serve static files
app.use(express.static(SKYNET_DOCROOT));

app.get('/', function (req, res) {
  //res.sendfile(__dirname + '/index.html');
  res.sendFile(SKYNET_DOCROOT + '/index.html');
});

app.get('/hello.txt', function(req, res){
  console.log('-------\nSkynet server GET /hello.txt');
  var body = 'Hello World?';
  res.setHeader('Content-Type', 'text/plain');
  res.setHeader('Content-Length', body.length);
  res.end(body);
});

// declare functions to process messages from web clients

// BROWSER SOCKET HANDLING CODE

// error, warn, info, debug
//web_socket.set('log level', 1);

console.log('Skynet web server listening on websocket');

web_socket.on('connection', function (client_socket) {
    console.log('-------\nSkynet web server websocket browser connection event');

    // initialize the hosts area on the connecting browser
    browser_refresh(client_socket);

    client_socket.on('message', function (msg) {
        console.log('------- Skynet web server websocket Message Received from browser:')
        console.log(msg);
        //-----------------------------------------------------
        // process message
        //-----------------------------------------------------
        process_browser_message(client_socket, msg);
    });

    client_socket.on('disconnect', function () {
        console.log('-------\nSkynet web server websocket browser disconnect event');
    });
});

// called when browser first connects its websocket
function browser_refresh(client_socket)
{
    console.log('---- Skynet browser_refresh ---');
    var all_nodes = ppc.all();
    for (var i=0; i<all_nodes.length; i++)
    {
        var node_name = all_nodes[i];
        //console.log('Status for ',node_name);
        var status = ppc.get(node_name);
        //console.log('Status is ', status);
        if (ppc.connected(node_name))
        {
            browser_send( client_socket,
                          { userid: 'skynet',
                            zone: 'skynet',
                            event_type: PPC_CONNECTED,
                            host_name: status.host_name,
                            slot_name: status.slot_name });
            browser_send( client_socket,
                          { userid: 'skynet',
                            zone: 'skynet',
                            event_type: PPC_STATUS,
                            host_name: status.host_name,
                            slot_name: status.slot_name,
                            data: status.status
                            });
        }
    }
}

function do_browser_command(msg)
{
    // message from browser begins "skynet..." i.e. this is a command to the skynet server
    // (as opposed to "ppc..." or just plain text)
    console.log('---- Skynet do_browser_command:',msg);
    var words = msg.split(" ");
    if (words.length < 2)
    {
        console.log('---- Skynet do_browser_command: bad command (short):',msg);
        return;
    }
    switch (words[1])
    {
        // skynet split <host> <slot>
        case 'split':
            console.log('---- Skynet splitting ppc: ',words[2],words[3]);
            ppc_send_msg(make_nn(words[2],words[3]),PPC_CMD_SPLIT);
            break;

        // skynet kill <host> <slot>
        case 'kill':
            console.log('---- Skynet killing ppc: ',words[2],words[3]);
            ppc_send_msg(make_nn(words[2],words[3]),PPC_CMD_KILL);
            break;

        // skynet disconnect <host> <slot>
        case 'disconnect':
            console.log('---- Skynet shutting down ppc: ',words[2],words[3]);
            ppc_send_msg(make_nn(words[2],words[3]),PPC_CMD_SHUTDOWN);
            break;

        // skynet send <host> <slot> <message>
        case 'send':
            var node_name = make_nn(words[2],words[3]);
            console.log('---- Skynet send to ppc ', node_name);
            if (words.length < 5)
            {
                console.log('---- Skynet bad send command: '+msg);
                return;
            }
            // accumulate remaining strings into ppc_msg
            var ppc_msg = words[4];
            for (var i=5; i<words.length; i++) ppc_msg += ' '+words[i];

            // send ppc_msg to just the required path processor
            ppc_send_msg(node_name, ppc_msg+"\n");
            break;

        // skynet bfp <proc> <processor count>
        // e.g. skynet bfp kappa 12
        // means send 'run kappa 0 12 N' to 12 path processors, with N 0..11
        case 'bfp':
            console_log('---- Skynet bfp ---');
            if (words.length < 3)
            {
                console.log('---- Skynet bad bfp command: '+msg);
                return;
            }
            var proc = words[2];
            var G = words[3];
            // reset any PPC's still reserved from last bfp run
            ppc.reserve_reset();
            // 'reserve' the required number of ppc's
            if (ppc.reserve(G))
            {
                // initiate BFP run (no split ppc node_name, initial Orc is 'init')
                split_assign('',proc,'init',G);
            } else {
                // we didn't get the required number of ppc's so warn user
                browser_broadcast({ userid: 'skynet',
                    zone: 'skynet',
                    event_type: SKYNET_WARNING,
                    data: 'Not enough path processors for bfp '+G
                    });
            }
            break;

        // skynet set <varname> <value>
        case 'set':
            console_log('---- Skynet set ');
            if (words.length < 4)
            {
                console.log('---- Skynet bad set command: '+msg);
                return;
            }
            // pick out var name to be set
            var varname = words[2];
            // accumulate remaining strings into value
            var value = words[3];
            for (var i=4; i<words.length; i++) value += ' '+words[i];

            // set skynet variable (convert to int if needed)
            if (isNaN(parseInt(value)) || words.length > 4)
            {
                vars[varname] = value;
                console_log('set vars['+varname+'] to "'+vars[varname]+'"');
            } else {
                vars[varname] = parseInt(value);
                console_log('set vars['+varname+'] to '+vars[varname]);
            }
            break;

        default:
            console.log('---- Skynet do_browser_command: bad command (unrecognized):',msg);
    }
}

    // incoming messages are processed here.
    // the default is to act as a simple REFLECTOR and re-broadcast
function process_browser_message(client_socket, msg)
{
    switch (msg.event_type)
    {
        case 'person_joined':
            console.log('browser connected to web server:',msg.userid);
            break;

        case 'user_input':
            // user has entered text on web page
            console.log('user_input received:',msg.userid);
            if (msg.data.toLowerCase().indexOf('skynet')==0)
            {
                do_browser_command(msg.data);
            } else {
                // will broadcast that text to all ppc's
                ppc_broadcast(msg.data+'\n');
            }
            break;

        default:
            console.log('---- browser message skipped ---');
            // by default we simple re-broadcast the message as a browser_broadcast
            // browser_broadcast(msg);
    }
}

    // This function sends a message to the requesting client.
function browser_send(client_socket, msg)
{
    console.log('------- Skynet server reply Shout Sent: ',msg,' ---')
    client_socket.emit('shout', msg);
}

//---------------------------------------------------------
// send shout message to all occupants of room
//---------------------------------------------------------

var browser_broadcast = function( msg )
{
    console.log('------- Skynet server browser Shout Sent to ALL')
    console.log(msg);
    //console.log('browser_broadcast (room:', msg.room,')', msg);
    // only send the shout to the room listed in the message
    web_socket.sockets.emit('shout', msg );
}

//-----------------------------------------------------
// log message in console
//-----------------------------------------------------

function timestamp()
{
    var d = new Date();
    var h = ("0"+d.getHours()).slice(-2);
    var m = ("0"+d.getMinutes()).slice(-2);
    var s = ("0"+d.getSeconds()).slice(-2);
    var ms = ("000"+d.getMilliseconds()).slice(-3);
    return h+':'+m+':'+s+'.'+ms;
}

function console_log(msg)
{
    console.log(timestamp()+' '+msg);
    return;
}

var process_options = function (req,res)
{
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Content-Length, X-Requested-With');

    res.send(200);
}

//*********************************************************************
//*********************************************************************
//*********** Skynet PPC socket server code     ***********************
//*********************************************************************
//*********************************************************************

function ppc_send_sock(socket, msg)
{
    console.log('--- Skynet server to PPC socket: <'+msg+'> ---');
    socket.write(msg);
}

function ppc_send_msg(node_name, msg)
{
    console.log('--- Skynet server to PPC: ', node_name, '<', msg,'> ---');
    if ( ppc.connected(node_name) )
    {
        var socket = ppc.socket(node_name);
        socket.write(msg);
    }
}

function ppc_broadcast(msg)
{
    console.log('--- Skynet PPC broadcast: <', msg,'> ---');
    var all_nodes = ppc.all();
    for (var i=0; i<all_nodes.length; i++)
    {
        ppc_send_msg(all_nodes[i], msg);
    }
}

// Called when any message arrives from PPC
// will pass to handle_ppc_line for each line of this message
function handle_ppc_msg(host_name, slot_name, msg)
{
    var lines = msg.split("\n");
    for (line in lines)
    {
        handle_ppc_line(host_name, slot_name, lines[line]);
    }
}

// Here is where we process each line of text that comes from the PPC
function handle_ppc_line(host_name, slot_name, msg)
{
    console_log('---- Skynet msg from ppc ('+host_name+':'+slot_name+') ' + msg);
    var node_name = make_nn(host_name, slot_name);

    // if no message, just skip
    if (!msg) return;

    // if message doesn't begin with 'skynet', just broadcast unchanged
    if (msg.indexOf(SKYNET)!=0)
    {
        browser_broadcast({ userid: 'skynet',
                        zone: 'skynet',
                        event_type: PPC_MSG,
                        host_name: host_name,
                        slot_name: slot_name,
                        data: msg
                        });
        return;
    }

    // process a message from the PPC to the SKYNET SERVER
    var words = msg.split(" ");
    // switch on second token of message
    switch (words[1]) {
        // got "skynet loaded Proc" from PPC
        case LOADED:
            ppc.set_status(node_name, PPC_WAITING);
            browser_broadcast({ userid: 'skynet',
                        zone: 'skynet',
                        event_type: PPC_STATUS,
                        host_name: host_name,
                        slot_name: slot_name,
                        data: PPC_WAITING
                        });
            break;

        // got "skynet running $PROC $O $G $N" from PPC
        case RUNNING:
            ppc.set_status(node_name, PPC_RUNNING);
            // expecting skynet running $PROC $O $G $N
            // accumulate remaining strings into ppc_msg
            var ppc_msg = words[2];
            for (var i=3; i<words.length; i++) ppc_msg += ' '+words[i];

            browser_broadcast({ userid: 'skynet',
                        zone: 'skynet',
                        event_type: PPC_RUNNING,
                        host_name: host_name,
                        slot_name: slot_name,
                        data: ppc_msg
                        });
            break;

        // got "skynet completed $PROC $O $G $N $work_required" from PPC
        case COMPLETED:
            // note we set status to 'WAITING' although we send 'completed' event to browser
            ppc.set_status(node_name, PPC_WAITING);

            // expecting skynet completed $PROC $O $G $N $WORK_COMPLETED
            // accumulate remaining strings into ppc_msg
            var ppc_msg = words[2];
            for (var i=3; i<words.length; i++) ppc_msg += ' '+words[i];

            browser_broadcast({ userid: 'skynet',
                        zone: 'skynet',
                        event_type: PPC_COMPLETED,
                        host_name: host_name,
                        slot_name: slot_name,
                        data: ppc_msg
                        });
            // now we check to see if we want to trigger the KAPPA process, and split a busy ppc
            if (check_kappa())
            {
                split_ppc();
            }
            break;

        // got "skynet split $remaining_work $work_done" from PPC
        // note $remaining_work is a proxy for Oracle
        case SPLIT:
            // accumulate remaining strings into ppc_msg
            var ppc_msg = words[2];
            for (var i=3; i<words.length; i++) ppc_msg += ' '+words[i];
            browser_broadcast({ userid: 'skynet',
                        zone: 'skynet',
                        event_type: PPC_SPLIT,
                        host_name: host_name,
                        slot_name: slot_name,
                        data: ppc_msg
                        });
            split_assign(node_name, 'kappa', words[2], vars['KAPPA']+1);
            break;

        // ppc rejected a split request (probably because it is completing anyway)
        case NOSPLIT:
            // accumulate remaining strings into ppc_msg
            var ppc_msg = words[2];
            for (var i=3; i<words.length; i++) ppc_msg += ' '+words[i];
            browser_broadcast({ userid: 'skynet',
                        zone: 'skynet',
                        event_type: PPC_NOSPLIT,
                        host_name: host_name,
                        slot_name: slot_name,
                        data: ppc_msg
                        });
            //ppc.unreserve(vars['KAPPA']);
            // re-issue a SPLIT request to another PPC
            nosplit_ppc();
            break;

        case EXIT:
            // note we set status to 'IDLE' although we send 'exit' event to browser
            ppc.set_status(node_name, PPC_IDLE);
            browser_broadcast({ userid: 'skynet',
                        zone: 'skynet',
                        event_type: PPC_EXIT,
                        host_name: host_name,
                        slot_name: slot_name
                        });
            break;

        default:
            // if we don't recognize it, or have nothing to do, just broadcast to browsers
            browser_broadcast({ userid: 'skynet',
                        zone: 'skynet',
                        event_type: PPC_MSG,
                        host_name: host_name,
                        slot_name: slot_name,
                        data: msg
                        });
    }
}

function make_nn(host_name, slot_name)
{
    return host_name+':'+slot_name;
}

var net = require('net');

net.createServer(function(socket){
    // host_name, slot_name populated when OK PPC_CMD_CONNECT message received from PPC
    var host_name = "";
    var slot_name = "";

    console.log('--- Skynet server: connection from PPC ---');
    ppc_send_sock(socket,PPC_CMD_CONNECT);

    socket.on('data', function(data){
        var msg = data.toString();

        if (msg.indexOf(OK + " " + PPC_CMD_CONNECT) == 0)
        {
            var connect_args = msg.split(" ");
            if (connect_args.length != 5)
            {
                console.log('---- Skynet server bad PPC_CMD_CONNECT received ---');
                return;
            } else {
                host_name = connect_args[3]; // store host_name:slot_name for future
                slot_name = connect_args[4];
                var node_name = make_nn(host_name, slot_name);
                // initialize entry in ppc_hosts for this connection
                ppc.add(node_name, {
                    host_name: host_name,
                    slot_name: slot_name,
                    socket: socket });

                ppc.connect(node_name); // sets ppc.connected(node_name) = true

                ppc.set_status(node_name, PPC_IDLE); // note initial status is connected & idle...

                browser_broadcast({ userid: 'skynet',
                        zone: 'skynet',
                        event_type: PPC_CONNECTED,
                        host_name: host_name,
                        slot_name: slot_name });
            }
        } else {
            handle_ppc_msg(host_name, slot_name, msg);
        }
        //var msg = browser_messages.make_message('skynet','from_ppc',data.toString());
        //browser_broadcast(msg);
        //socket.write(data.toString().toUpperCase())
    });

    socket.on('end', function(){
        console.log('---- Skynet server received PPC disconnect. ', host_name, slot_name);
        if (typeof(host_name) == "undefined" | !host_name) return;
        ppc.disconnect(make_nn(host_name,slot_name));
        browser_broadcast({ userid: 'skynet',
                zone: 'skynet',
                event_type: PPC_DISCONNECTED,
                host_name: host_name,
                slot_name: slot_name });
    });

    socket.on('error', function(){
        console.log('---- Skynet PPC socket error. ', host_name, slot_name);
        ppc.disconnect(make_nn(host_name,slot_name));
        browser_broadcast({ userid: 'skynet',
                zone: 'skynet',
                event_type: PPC_DISCONNECTED,
                host_name: host_name,
                slot_name: slot_name });
    });
}).listen(SKYNET_PPC_PORT);

console.log('Skynet server ready');
