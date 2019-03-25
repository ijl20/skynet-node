
#include <stdio.h>


void main(int argc, char *argv[])
{
    char buf[100];
    int  n_written;

    while (fgets(buf,100,stdin) != NULL) {
	fprintf(stderr,"a>>%s",buf);
	printf(">%s",buf);
	if (fflush(stdout) == EOF) {fprintf(stderr,"aaargh\n"); exit(1);}
	/*         n_written = write(1,buf,strlen(buf)); */
	fprintf(stderr,"b>>%s",buf);
    }
}
