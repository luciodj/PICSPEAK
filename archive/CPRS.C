/*
** programma di aiuto nella compressione di file di campioni audio
**
*/
#include <stdio.h>

void main()
{
    int i, j;
    int len, max, min, delta, prev;
    FILE *fp;
    char  fname[80];    /* nome del file */
    unsigned char  buffer[256];    /* buffer campioni */

    fprintf(stderr, "Load file: ");
    while (scanf("%s", fname) < 1);
    fprintf(stderr, "\n");

    if ((fp= fopen(fname, "rb")) == NULL)
    {
        fprintf(stderr, "Non trovo il file: %s\n", fname);
        exit(1);    /* esce con errore */
    }

    if ((len= fread( buffer, 1, 256, fp)) == 0)
    {
        fprintf(stderr, "File vuoto \n");
        exit(1);
    }

    printf("Tot: %d campioni\n", len);
    delta= 0;
    max= 0;
    min= 255;
    prev= buffer[0];
    for ( i=0; i< len; i++)
    {
        printf("\tretlw\t%03x\n", buffer[i]);
        if (buffer[i] > max)
            max= buffer[i];
        if (buffer[i] <= min)
            min= buffer[i];

        prev= buffer[i] - prev;
        if (prev < 0) prev= -prev;
/*        if (prev > 8)
            printf("!");
*/
        if (prev > delta)
            delta= prev;
        prev= buffer[i];
    }

    printf("\n; max: %3d    min: %3d  deltamax: %3d\n", max-128, min-128, delta);
}

