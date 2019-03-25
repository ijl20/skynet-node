/*
 * Path Processor server program to spawn and control user Child program
 */

#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <string.h>
#include <signal.h>
#include <errno.h>
#include <stdlib.h>

#define SKYNET_SRV_PORT 10083 
#define SKYNET_SRV_NAME "localhost"
#define SKYNET_SRV_IP "127.0.0.1"

/* signal send to child when 'split' command received */
#define SPLIT_SIGNAL SIGHUP

#define MSG_SIZE 12
#define COMMAND_LENGTH 4

#define CHILD 0
#define CONTROLLER 1

#define MAX_BUF 4096

#define TO_CHILD to_child[1]
#define FROM_CHILD to_control[0]

#define MAX_VARS 100
#define VAR_SIZE 300
#define MAX_COMMAND 30
#define MAX_PROG 100
#define MAX_ARGS 18
#define ARG_LEN 100

//***********************************************************
//**************** Commands received from Skynet  ***********
//***********************************************************
#define PPC "ppc"
#define CONNECT "connect"
#define READ_VAR "read_var"
#define SET_VAR  "set_var"
#define START "start"
#define CHILD_SEND "child_send"
#define KILL "kill"
#define SPLIT "split"
#define CLOSE    "close"
#define SHUTDOWN "shutdown"

//****** Response prefix for messages to Skynet
#define OK       "ok"
#define NOK      "nok"

/********************************************************** */
/***** Messages from PPC to Skynet                  ******* */
#define SKYNET_EXIT "skynet exit"

/************************************************************************/
/*           Prototypes                                                 */
/************************************************************************/

void skynet_send_msg(char *msg);
int skynet_get_msg(int fd, char *buf);
void err_exit(char *msg);
int do_command(int *cont);
void init_vars();
void read_var(char *var_name, char *var_value);
void set_var(char *var_name, char *var_value);
int start_prog(char *command);
int child_send_msg(char *msg);
int child_get_msg(void);
void child_signal(int);

/************************************************************************/
/*           Globals                                                    */
/************************************************************************/

static int sock_fd;

int pid;                         /* pid of Child process                */
int to_child[2], to_control[2];  /* pipes to connect to child           */
int child_running = 0;           /* boolean flag true if child running  */
fd_set fd_var;                   /* set of file-descriptors for select  */

char host_name[200], slot_name[200];    /* from argv[1] and argv[2] */

char vars[MAX_VARS][VAR_SIZE];

/************************************************************************/
/*               Send message to Skynet                                 */
/************************************************************************/

void skynet_send_msg(char *msg)
{
  int n_written, msg_size;
  printf("ppc: skynet_send_msg: <%s>\n",msg);
  fflush(stdout);
  msg_size = strlen(msg);
  n_written = write(sock_fd, msg, msg_size);
  if (n_written < msg_size) err_exit("ppc: skynet_send_msg: n_written");
}

/************************************************************************/
/*                    skynet_get_msg                                          */
/************************************************************************/

int skynet_get_msg(int fd, char *buf)
{
  int nread;
      /* fprintf(stderr, "in skynet_get_msg i=%d\n",i);  */
  nread = read(fd, buf, MAX_BUF);
      /* fprintf(stderr, "leaving skynet_get_msg i=%d\n",i); */
  buf[nread] = '\0';
  printf("ppc: skynet_get_msg: <%s>\n",buf);
  return nread;
}

/************************************************************************/
/*               do_command                                             */
/************************************************************************/

int do_command(int *cont)
{
    int n_read, n_written, command_cont = 1;
    char buffer_in[MAX_BUF], buffer_out[MAX_BUF];
    char command[MAX_COMMAND];
    char var_name[VAR_SIZE], var_value[VAR_SIZE];

    *cont = 1;

    n_read = skynet_get_msg(sock_fd, buffer_in);
    if ( n_read == 0 )
      {
        printf("ppc do_command: zero chars from skynet_get_msg\n");
        return(0);
      }
    /* get first word as command
       if it's PPC then this is a command local to this path processor
       if anything else then just send to child
    */
    sscanf(buffer_in,"%s",command);
    printf("ppc do_command: %s\n",command);
    /* check if first word is NOT "ppc" */ 
    if (strcmp(command,PPC) != 0)
    {
        /* this is NOT a ppc command, so send to child */
        if (child_send_msg(buffer_in) == 0)
          { /* sprintf(buffer_out,"%s %s",OK,buffer_in);
               skynet_send_msg(buffer_out) */;
          }
        else
          { 
            printf("ppc do_command child_send_msg error: %s",buffer_in);
            sprintf(buffer_out,"%s %s",NOK,buffer_in);
            skynet_send_msg(buffer_out);
          }

        return(1);
    }
    /* command is 'ppc' so now check second word */
    sscanf(buffer_in,"ppc %s",command);
    printf("ppc do_command PPC command %s\n",command);
    if (strcmp(command,CONNECT) == 0)
      {
        sprintf(buffer_out,"%s %s %s %s",OK, buffer_in, host_name, slot_name);
        skynet_send_msg(buffer_out);
      }
    else if (strcmp(command,SET_VAR) == 0)
      {
        sscanf(buffer_in, "%*s %s %s",var_name, var_value);
        set_var(var_name, var_value);
        sprintf(buffer_out,"%s %s",OK, buffer_in);
        skynet_send_msg(buffer_out);
      }
    else if (strcmp(command,READ_VAR) == 0)
      {
        sscanf(buffer_in, "%*s %s",var_name);
        read_var(var_name, var_value);
        sprintf(buffer_out,"%s %s",OK, buffer_in);
        skynet_send_msg(buffer_out);
        sprintf(buffer_out,"%s %s %s\n", command, var_name, var_value);
        skynet_send_msg(buffer_out);
      }        
    else if (strcmp(command,START) == 0)
      {
        if (child_running)
          sprintf(buffer_out,"%s %s child running\n",NOK,START);  
        else if (start_prog(buffer_in + strlen(PPC) + 1 + strlen(START)) == 0)
          { 
            printf("ppc: start ok: %s", buffer_in + strlen(PPC) + 1 + strlen(START));
            /* sprintf(buffer_out,"%s %s",OK,buffer_in);
               skynet_send_msg(buffer_out) */;
          }
        else
          { sprintf(buffer_out,"%s %s",NOK,buffer_in);
            skynet_send_msg(buffer_out);
          }
      }
    else if (strcmp(command,CHILD_SEND) == 0)
      {
        if (child_send_msg(buffer_in+strlen(CHILD_SEND)) == 0)
          { /* sprintf(buffer_out,"%s %s",OK,buffer_in);
               skynet_send_msg(buffer_out) */;
          }
        else
          { sprintf(buffer_out,"%s %s",NOK,buffer_in);
            skynet_send_msg(buffer_out);
          }
      }
    else if (strcmp(command,KILL) == 0)
      {
        if (kill(pid,SIGKILL) == 0)
          sprintf(buffer_out,"%s %s\n",OK,buffer_in);
        else
          sprintf(buffer_out,"%s %s\n",NOK,buffer_in);
        skynet_send_msg(buffer_out);
      }
    else if (strcmp(command,SPLIT) == 0)
      {
        printf("ppc: do_command split - sending signal %d to pid %d\n", SPLIT_SIGNAL, pid);
        if (kill(pid,SPLIT_SIGNAL) == 0)
          { /* sprintf(buffer_out,"%s %s",OK,buffer_in);
               skynet_send_msg(buffer_out) */;
            printf("ppc: do_command split - signal %d to pid %d OK\n", SPLIT_SIGNAL, pid);
          }
        else
          { sprintf(buffer_out,"%s %s",NOK,buffer_in);
            skynet_send_msg(buffer_out);
          }
      }
    else if (strcmp(command,SHUTDOWN) == 0)
      {
        sprintf(buffer_out,"%s %s",OK,buffer_in);
        n_written = write(sock_fd,buffer_out,strlen(buffer_out));
        if (n_written != strlen(buffer_out))
          err_exit("ppc: do_commands: SHUTDOWN nwritten");
        close(sock_fd);
        command_cont = 0;
        *cont = 0;
      }
    else if (strcmp(command,CLOSE) == 0)
      {
        sprintf(buffer_out,"%s %s",OK,buffer_in);
        n_written = write(sock_fd,buffer_out,strlen(buffer_out));
        if (n_written != strlen(buffer_out))
          err_exit("ppc: do_commands: CLOSE nwritten");
        close(sock_fd);
        command_cont = 0;
      }
    else
      {
        // unrecognized command from skynet - send back "nok <command>"
        sprintf(buffer_out,"%s %s",NOK, buffer_in);
        skynet_send_msg(buffer_out);
      }

    return(command_cont);
}

/************************************************************************/
/*                    err_exit                                          */
/************************************************************************/

void err_exit(char *msg)
{
 close(sock_fd);
 printf("%s\n",msg);
 exit(1);
}

/************************************************************************/
/*                        init_vars                                     */
/************************************************************************/

void init_vars()
{
 int i;
 for (i=0;i<MAX_VARS;i++) vars[i][0] = '!'; /* skynet vars alphanumeric */
}  

/************************************************************************/
/*                        read_var                                      */
/************************************************************************/

void read_var(char *var_name, char *var_value)
{
  int i = 0;
  while (i<MAX_VARS)
    {
      if (vars[i][0] == '!')
        { var_value[0] = '!';
          i = MAX_VARS;
        }
      else if (strcmp(vars[i],var_name) == 0)
        { strcpy(var_value, vars[i]+strlen(var_name)+1);
          printf("ppc: read_var: %s in vars[%d] is %s\n",
                 var_name, i, var_value);
          i = MAX_VARS;
	}
      else i++;
      
    }
}

/************************************************************************/
/*                        set_var                                       */
/************************************************************************/

void set_var(char *var_name, char *var_value)
{
  int i = 0;
  while (i<MAX_VARS)
    {
      if ((vars[i][0] == '!') || (strcmp(vars[i],var_name) == 0))
        { strcpy(vars[i], var_name);
          strcpy(vars[i]+strlen(var_name)+1, var_value);
          printf("ppc: set_var: %s %s into vars[%d]\n",
                 var_name, var_value, i);
          i = MAX_VARS;
	}
      else i++;
    }
}

/************************************************************************/
/*                        start_prog                                    */
/************************************************************************/

int start_prog(char *command)
{
  char argv[MAX_ARGS][ARG_LEN];
  char *argvp[MAX_ARGS];
  int i;

  /* initialize argv array */

  for (i=0;i<MAX_ARGS;i++) argv[i][0] = '\0';
  sscanf(command,"%s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s",
                 argv[0], argv[1], argv[2], argv[3], argv[4], argv[5],
                 argv[6], argv[7], argv[8], argv[9], argv[10], argv[11],
                 argv[12], argv[13], argv[14], argv[15], argv[16]);
  for (i=0;i<MAX_ARGS;i++)
    argvp[i] = (argv[i][0] == '\0') ? (char *) NULL : argv[i];
  /* setup pipes */
  if (pipe(to_child) < 0) err_exit("ppc: start_prog: bad pipe to_child");
  if (pipe(to_control) < 0) err_exit("ppc: start_prog: bad pipe to_control");

  /* spawn process */
  if ((pid = fork()) < 0) err_exit("ppc: start_prog: bad fork");
  else if (pid == 0)
    {
      close(0);              /* close child stdin */
      dup(to_child[0]);     /* to_child[0] is child stdin */
      close(1);              /* close child stdout */
      dup(to_control[1]);    /* control[1] is child stdout */
      close(to_child[1]);   /* close unnecessary file descriptors */ 
      close(to_child[0]);
      close(to_control[0]);
      close(to_control[1]);
      if (execvp(argv[0], argvp) < 0)
        {
          exit(0);   /* bad exec so child exits */
        }
    }

  /* parent */
  child_running = 1;
  close(to_child[0]);    /*     close unnecessary file descriptors  */
  close(to_control[1]);
  printf("ppc: %s (pid = %d) started\n", argv[0], pid);
  fflush(stdout);
  return(0);
}

/************************************************************************/
/*               child_send_msg                                             */
/************************************************************************/

int child_send_msg(char *msg)
{
  int n_written, msg_size;
  printf("ppc: send_child_msg: sending <%s>\n",msg);
  fflush(stdout);
  msg_size = strlen(msg);
  n_written = write(TO_CHILD, msg, msg_size);
  if (n_written < msg_size) err_exit("ppc: send_child_msg: n_written");
  return 0;
}

/************************************************************************/
/*               child_get_msg                                              */
/************************************************************************/

int child_get_msg(void)
{
  char buf[MAX_BUF];
  int nread;
  if (child_running == 0) return 0;
      /* fprintf(stderr, "in skynet_get_msg i=%d\n",i);  */
  nread = read(FROM_CHILD, buf, MAX_BUF);
      /* fprintf(stderr, "leaving skynet_get_msg i=%d\n",i); */
  if (nread <= 0)
    { child_running = 0;
      close(FROM_CHILD);
      printf("%s","ppc: connection FROM_CHILD closed\n");
      fflush(stdout);
      return nread;
    }
  else
    {
      buf[nread] = '\0';
      printf("ppc: child_get_msg: <%s>\n",buf);
      fflush(stdout);
      skynet_send_msg(buf);
      return 0;
    }
}

/************************************************************************/
/*         child_signal - called when child process stops or terminates */
/************************************************************************/

void child_signal(int sig)
{
  //union wait status;
  char buffer_out[MAX_BUF];

  if (sig == SIGCHLD)
    {
      printf("%s","ppc: SIGCHLD\n");
      fflush(stdout);
      while (child_get_msg()) {};        /* flush read pipe from child */
      /* child_running = 0; */
      close(TO_CHILD);
      //while (wait3(&status, WNOHANG, 0) > 0) /* reap child */
        ;
      /* sprintf(buffer_out,"%s child exitted\n",OK);*/
      skynet_send_msg(SKYNET_EXIT);
    }
  else err_exit("ppc: child_signal");
}

/************************************************************************/
/*                        main                                          */
/************************************************************************/

void main(int argc, char *argv[])
{
    int retval, sv_len, cl_len, cont = 1, command_cont;
    struct sockaddr_in cl_addr, sv_addr;
    struct hostent *server;

    int max_fd;
    char buf[MAX_BUF];              /* message buffer for child             */
    int  i = 0;                 /* message count */

                              /* max fd calculation for select */

    if (argc <  3) 
    {
    printf("ppc: Usage %s <hostname> <slotname>\n", argv[0]);
    err_exit("ppc: hostname/slotname missing in call");
    }

    strcpy(host_name, argv[1]);
    strcpy(slot_name, argv[2]);

    printf("ppc: host_name, slot_name is %s %s\n",host_name, slot_name);

    /* start up message */
    printf("ppc: %s-%s started\n", argv[0], argv[1]);

    /* register SIGCHLD handler */
    if (signal(SIGCHLD,child_signal) == SIG_ERR) err_exit("ppc: signal");
    init_vars();

    if ( (sock_fd = socket(AF_INET, SOCK_STREAM, 0)) < 0)  /* open socket */
    err_exit("ppc: can't open stream socket");

    bzero( (char *) &sv_addr, sizeof(sv_addr));       /* NULLS -> sv_addr */

    sv_addr.sin_family = AF_INET;         /* build struct sv_addr, sv_len */

    sv_addr.sin_addr.s_addr = inet_addr(SKYNET_SRV_IP);

    sv_addr.sin_port       = htons(SKYNET_SRV_PORT);

    printf("ppc: connecting to %s:%d",SKYNET_SRV_IP,SKYNET_SRV_PORT);

    if (connect(sock_fd,(struct sockaddr *) &sv_addr,sizeof(sv_addr)) < 0) 
    {
        err_exit("ppc: ERROR connecting to Skynet");
    }
    printf("%s","ppc: connected to Skynet\n");

    //sprintf(buf,"%s %s %s %s\n",OK,SKY_CONNECT, host_name, slot_name);
    //skynet_send_msg(buf);
    
    command_cont = 1;
    while (command_cont)
      {
        FD_ZERO(&fd_var);      /* initialize file-descriptor set for select */
        FD_SET(sock_fd, &fd_var);
        printf("ppc: sock_fd = %d, FROM_CHILD = %d\n",sock_fd, FROM_CHILD);
        fflush(stdout);
        do
          { if (child_running)
              { FD_SET(FROM_CHILD, &fd_var);
                max_fd = (FROM_CHILD > sock_fd) ? 
                              FROM_CHILD + 1 :
                              sock_fd + 1;  
              }
            else max_fd = sock_fd + 1;
            printf("ppc: max_fd = %d, calling select...\n", max_fd);
            fflush(stdout);
            retval = select( max_fd, &fd_var /*reads*/, 
                                    (fd_set *) NULL /*writes*/,
                                    (fd_set *) NULL /*excpts*/,
                                    (struct timeval *) NULL);
          }
        while ((retval < 0) && (errno == EINTR));
        if (retval < 0) err_exit("ppc: bad select");
        printf("ppc: back from select, testing fd_var...\n");
        fflush(stdout);
        if (FD_ISSET(sock_fd, &fd_var)) command_cont = do_command(&cont);
        if (FD_ISSET(FROM_CHILD, &fd_var)) child_get_msg();
      }
}
