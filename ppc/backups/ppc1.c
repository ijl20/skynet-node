/*
 * Path Processor server program to spawn and control user Child program
 */

#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <string.h>
#include <signal.h>

#define SERV_TCP_PORT 6173

#define MSG_SIZE 12
#define COMMAND_LENGTH 4

#define CHILD 0
#define CONTROLLER 1

#define QUIT_COMMAND "quit"

#define MAX_BUF 4096

#define TO_CHILD to_child[1]
#define FROM_CHILD to_control[0]

#define MAX_VARS 100
#define VAR_SIZE 300
#define MAX_COMMAND 30
#define MAX_PROG 100
#define MAX_ARGS 18
#define ARG_LEN 100

#define READ_VAR "read_var"
#define SET_VAR  "set_var"
#define SHUTDOWN "shutdown"
#define CLOSE    "close"
#define START_PROG "start_prog"
#define SKY_CONNECT "sky_connect"
#define SEND_CHILD "send_child"
#define KILL_CHILD "kill_child"

#define OK       "ok "
#define NOK      "nok "

/************************************************************************/
/*           Prototypes                                                 */
/************************************************************************/

void send_msg(char *msg);
int get_msg(int fd, char *buf);
void err_exit(char *msg);
int do_command(int *cont);
void init_vars();
void read_var(char *var_name, char *var_value);
void set_var(char *var_name, char *var_value);
int start_prog(char *command);
int send_child(char *msg);
void get_child(void);
void child_signal(int);

/************************************************************************/
/*           Globals                                                    */
/************************************************************************/

static int sock_fd, newsock_fd;

int pid;                         /* pid of Child process                */
int to_child[2], to_control[2];  /* pipes to connect to child           */
int child_running = 0;           /* boolean flag true if child running  */
fd_set fd_var;                   /* set of file-descriptors for select  */

char vars[MAX_VARS][VAR_SIZE];

/************************************************************************/
/*               send_msg                                               */
/************************************************************************/

void send_msg(char *msg)
{
  int n_written, msg_size;
  printf("ppc: send_msg: sending <%s>\n",msg);
  fflush(stdout);
  msg_size = strlen(msg);
  n_written = write(newsock_fd, msg, msg_size);
  if (n_written < msg_size) err_exit("ppc: send_msg: n_written\n");
}

/************************************************************************/
/*                    get_msg                                          */
/************************************************************************/

int get_msg(int fd, char *buf)
{
  int nread;
      /* fprintf(stderr, "in get_msg i=%d\n",i);  */
  nread = read(fd, buf, MAX_BUF);
      /* fprintf(stderr, "leaving get_msg i=%d\n",i); */
  buf[nread] = '\0';
  fprintf(stderr,"ppc: get_msg: <%s>\n",buf);
  return nread;
}

/************************************************************************/
/*               do_commands(sock_fd, client_fd)                        */
/************************************************************************/

int do_command(int *cont)
{
  int n_read, n_written, command_cont = 1;
  char buffer_in[MAX_BUF], buffer_out[MAX_BUF];
  char command[MAX_COMMAND];
  char var_name[VAR_SIZE], var_value[VAR_SIZE];

  *cont = 1;

    n_read = get_msg(newsock_fd, buffer_in);
    if ( n_read == 0 )
       err_exit("server: do_commands: zero chars from get_msg\n");
    sscanf(buffer_in,"%s",command);
    printf("ppc: %s\n",command);
    if (strcmp(command,SET_VAR) == 0)
      {
        sscanf(buffer_in, "%*s %s %s",var_name, var_value);
        set_var(var_name, var_value);
        sprintf(buffer_out,"%s%s",OK, buffer_in);
        send_msg(buffer_out);
      }
    else if (strcmp(command,READ_VAR) == 0)
      {
        sscanf(buffer_in, "%*s %s",var_name);
        read_var(var_name, var_value);
        sprintf(buffer_out,"%s%s",OK, buffer_in);
        send_msg(buffer_out);
        sprintf(buffer_out,"%s %s %s\n", command, var_name, var_value);
        send_msg(buffer_out);
      }        
    else if (strcmp(command,START_PROG) == 0)
      {
        if (start_prog(buffer_in + strlen(START_PROG)) == 0)
          sprintf(buffer_out,"%s%s",OK,buffer_in);
        else
          sprintf(buffer_out,"%s%s",NOK,buffer_in);
        send_msg(buffer_out);
      }
    else if (strcmp(command,SEND_CHILD) == 0)
      {
        if (send_child(buffer_in+strlen(SEND_CHILD)) == 0)
          sprintf(buffer_out,"%s%s",OK,buffer_in);
        else
          sprintf(buffer_out,"%s%s",NOK,buffer_in);
        send_msg(buffer_out);
      }
    else if (strcmp(command,KILL_CHILD) == 0)
      {
        child_running = 0;
        if (kill(pid,SIGKILL) == 0)
          sprintf(buffer_out,"%s%s",OK,buffer_in);
        else
          sprintf(buffer_out,"%s%s",NOK,buffer_in);
        send_msg(buffer_out);
      }
    else if (strcmp(command,SHUTDOWN) == 0)
      {
        sprintf(buffer_out,"%c%s",'X',buffer_in);
        n_written = write(newsock_fd,buffer_out,strlen(buffer_out));
        if (n_written != strlen(buffer_out))
          err_exit("ppc: do_commands: SHUTDOWN nwritten\n");
        close(newsock_fd);
        close(sock_fd);
        command_cont = 0;
        *cont = 0;
      }
    else if (strcmp(command,CLOSE) == 0)
      {
        sprintf(buffer_out,"%c%s",'X',buffer_in);
        n_written = write(newsock_fd,buffer_out,strlen(buffer_out));
        if (n_written != strlen(buffer_out))
          err_exit("ppc: do_commands: CLOSE nwritten\n");
        close(newsock_fd);
        command_cont = 0;
      }
    else
      {
        sprintf(buffer_out,"%s%s",NOK, buffer_in);
        send_msg(buffer_out);
      }

  return(command_cont);
}

/************************************************************************/
/*                    err_exit                                          */
/************************************************************************/

void err_exit(char *msg)
{
 close(sock_fd);
 close(newsock_fd);
 printf(msg);
 exit(1);
}

/************************************************************************/
/*                        init_vars                                     */
/************************************************************************/

void init_vars()
{
 int i;
 for (i=0;i<MAX_VARS;i++) vars[i][0] = NULL;
}  

/************************************************************************/
/*                        read_var                                      */
/************************************************************************/

void read_var(char *var_name, char *var_value)
{
  int i = 0;
  while (i<MAX_VARS)
    {
      if (vars[i][0] == NULL)
        { var_value[0] = NULL;
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
      if ((vars[i][0] == NULL) || (strcmp(vars[i],var_name) == 0))
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
/*                        main                                          */
/************************************************************************/

void main(int argc, char *argv[])
{
  int child_pid, sv_len, cl_len, cont = 1, command_cont = 1;
  struct sockaddr_in cl_addr, sv_addr;
  char *proc_name;
  int max_fd;
  char buf[MAX_BUF];              /* message buffer for child             */
  int  i = 0;                 /* message count */
                              /* max fd calculation for select */
  proc_name = argv[0];
  /* start up message */
  printf("%s started\n", proc_name);

  if (signal(SIGCHLD,child_signal) == SIG_ERR) err_exit("ppc: signal\n");
  init_vars();

  if ( (sock_fd = socket(AF_INET, SOCK_STREAM, 0)) < 0)  /* open socket */
    err_exit("server: can't open stream socket\n");

  bzero( (char *) &sv_addr, sizeof(sv_addr));       /* NULLS -> sv_addr */

  sv_addr.sin_family = AF_INET;         /* build struct sv_addr, sv_len */

  sv_addr.sin_addr.s_addr = htonl(INADDR_ANY);

  sv_addr.sin_port       = htons(SERV_TCP_PORT);
                                        /* bind */
  if ( bind(sock_fd, (struct sockaddr *) &sv_addr, sizeof(sv_addr)) < 0)
    { close(sock_fd);
      err_exit("server: can't bind local address\n");
    }

  listen(sock_fd, 5);                                         /* listen */
                                          /* wait for client connection */
  while (cont)
  {
    cl_len = sizeof(cl_addr);
                                                              /* accept */
    newsock_fd = accept(sock_fd, (struct sockaddr *) &cl_addr, &cl_len);
    if (newsock_fd < 0) err_exit("server: accept error\n");
    sprintf(buf,"%s%s\n",OK,SKY_CONNECT);
    send_msg(buf);
    while (command_cont)
      {
        FD_ZERO(&fd_var);      /* initialize file-descriptor set for select */
        FD_SET(newsock_fd, &fd_var);
        printf("newsock_fd = %d, FROM_CHILD = %d\n",newsock_fd, FROM_CHILD);
        fflush(stdout);
        if (child_running)
          { FD_SET(FROM_CHILD, &fd_var);
            max_fd = (FROM_CHILD > newsock_fd) ? 
                          FROM_CHILD + 1 :
                          newsock_fd + 1;  
          }
        else max_fd = newsock_fd + 1;
        printf("max_fd = %d, calling select...\n", max_fd);
        fflush(stdout);
        if (select( max_fd, &fd_var /*reads*/, (fd_set *)NULL /*writes*/,
                   (fd_set *) NULL /*excpts*/, (struct timeval *) NULL) < 0)
           err_exit("ppc: bad select\n");
        printf("back from select, testing fd_var...\n");
        fflush(stdout);
        if (FD_ISSET(newsock_fd, &fd_var)) command_cont = do_command(&cont);
        if (FD_ISSET(FROM_CHILD, &fd_var)) get_child();
      }
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
  if (pipe(to_child) < 0) err_exit("ppc: start_prog: bad pipe to_child\n");
  if (pipe(to_control) < 0) err_exit("ppc: start_prog: bad pipe to_control\n");

  /* spawn process */
  if ((pid = fork()) < 0) err_exit("ppc: start_prog: bad fork\n");
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
  printf("%s (pid = %d) started\n", argv[0], pid);
  fflush(stdout);
  return(0);
}

/************************************************************************/
/*               send_child                                             */
/************************************************************************/

int send_child(char *msg)
{
  int n_written, msg_size;
  printf("ppc: send_child_msg: sending <%s>\n",msg);
  fflush(stdout);
  msg_size = strlen(msg);
  n_written = write(TO_CHILD, msg, msg_size);
  if (n_written < msg_size) err_exit("ppc: send_child_msg: n_written\n");
  return 0;
}

/************************************************************************/
/*               get_child                                              */
/************************************************************************/

void get_child(void)
{
  char buf[MAX_BUF];
  int nread;
      /* fprintf(stderr, "in get_msg i=%d\n",i);  */
  nread = read(FROM_CHILD, buf, MAX_BUF);
      /* fprintf(stderr, "leaving get_msg i=%d\n",i); */
  if (nread <= 0)
    { child_running = 0;
      close(FROM_CHILD);
      printf("ppc: connection FROM_CHILD closed\n");
      fflush(stdout);
    }
  else
    {
      buf[nread] = '\0';
      printf("ppc: get_child: <%s>\n",buf);
      fflush(stdout);
      send_msg(buf);
    }
}

/************************************************************************/
/*               child_signal                                           */
/************************************************************************/

void child_signal(int sig)
{
  if (sig == SIGCHLD)
    {
      printf("ppc: SIGCHLD\n");
      fflush(stdout);
      close(TO_CHILD);
    }
  else err_exit("ppc: child_signal\n");
}
