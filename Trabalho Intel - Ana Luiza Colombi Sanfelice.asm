
	.model		small
	.stack
		
CR		equ		0dh
LF		equ		0ah

	.data

CMDLINE			db		20 dup (0),'$'	; Nome do arquivo
FileBuffer		db		200 dup (?)		; Buffer de leitura do arquivo
FileHandle		dw		0				; Handler do arquivo
BufferTec		db 		200 dup (?)

MAXSTRING		equ		200
String			db		MAXSTRING dup (?)
StringMaiuscula		db		MAXSTRING dup (?)
StringLen		db		1 dup (?)
Linha			dw		2 dup (?)
StrLinha		db		10 dup (?)
LinhaAtual		db		1000 dup (?)

Flaglinha1		db		2 dup (?)
Espacos			db		2 dup (?)

SN			db		4 dup (?)
BufferSN		db		4 dup (?)

MsgLinha		db	"Linha ", 0
MsgEspaco		db  	": ", 0
MsgPedePalavra		db	"-- Que palavra voce quer buscar?", CR, LF, 0
MsgErroOpenFile		db	"Erro na abertura do arquivo.", CR, LF, 0
MsgErroReadFile		db	"Erro na leitura do arquivo.", CR, LF, 0
MsgOcorrencias		db	"-- Foram encontradas as seguintes ocorrencias:", CR, LF, 0
MsgFimOcorrencias	db	"-- Fim das ocorrencias.", CR, LF, 0
MsgNovaPalavra		db	"-- Quer buscar outra palavra? (S/N)", CR, LF, 0
MsgNaoOcorrencias	db	"-- Nao foram encontradas ocorrencias.", CR, LF, 0
MsgEncerrando		db	"-- Encerrando.", CR, LF, 0
MsgPorfavor		db	"-- Por favor, somente S ou N.", CR, LF, 0
CrLf			db 	CR, LF, 0

H2D			db		10 dup (?)

sw_n			dw	0
sw_f			db	0
sw_m			dw	0

FlagProg			db 	0

	.code
	.startup
	
	push 		ds ; Salva as informacoes de segmentos
	push 		es
	mov 		ax, ds ; Troca DS com ES para poder usa o REP MOVSB
	mov 		bx, es
	mov 		ds, bx
	mov 		es, ax
	mov 		si, 80h ; Obtem o tamanho da linha de comando e coloca em CX
	mov 		ch, 0
	mov 		cl, [si]
	mov 		ax, cx ; Salva o tamanho do string em AX, para uso futuro
	mov 		si, 81h ; Inicializa o ponteiro de origem
	lea 		di, CMDLINE-1 ; Inicializa o ponteiro de destino
	rep 		movsb
	pop 		es ; retorna os dados dos registradores de segmentos
	pop 		ds

	
;====================================================================

Main:
	mov    		linha, 1	; começa do 1, pois pra primeira linha ser contada
	mov 		Flaglinha1, 1
	
	;	Solicita palavra a ser procurada
	call		GetString
	
	;	 Verifica se é válida
	lea     	si, String
    	call   		EhLetraOuNumero
    	cmp     	ax, 1
    	jne      	StringNValida

	;	Abre arquivo
	lea 		dx, CMDLINE
	call 		fopen
	jnc		Continua1
	
	;	Imprime mensagem de erro abertura arquivo
	lea		bx,MsgErroOpenFile	
	call		printf_s
	
	xor		si, si		; Indice para linha atual
	
Fim:	
	lea		bx, MsgNovaPalavra
	call		printf_s
	call		GetSN
	
	lea		si, SN
	mov		dl, byte ptr [si]
	
	cmp		dl, 'S'
	je		Main
	
	cmp		dl, 's'
	je		Main
	
	cmp		dl, 'N'
	je		RealFim
	
	cmp		dl, 'n'
	je		RealFim
	
	lea		bx, MsgPorfavor
	call		printf_s
	jmp		Fim

RealFim:
	lea		bx, MsgEncerrando
	call		printf_s
	
	.exit

;--------------------------------------------------------------
StringNValida:
	jmp		Main

;-----------------------------------------------------------------	
	
Continua1:
	; Salva handle do arquivo
	mov		FileHandle,ax
	lea		si, LinhaAtual	;Inicio linha
	lea		di, String		;Inicio string

LerProximoByte:
	mov		bx,FileHandle
	call		getChar
	jnc		Continua2
	
	;	Imprime mensagem de erro leitura arquivo
	lea		bx,MsgErroReadFile
	call		printf_s
	
	mov		al,1
	jmp		CloseAndRetorna

Continua2:
	; Se ax ==0, fecha arquivo
	cmp		ax,0
	je		CloseAndRetorna

	;Vê se é uma nova linha
	cmp		dl, CR
	je		CheckLF
	cmp		dl, LF
	je		FimDaLinha
	
	
	mov		[si], dl
	inc 		si
	jmp		LerProximoByte
	
CheckLF:
	 ; Se for CR, verifique o próximo caractere para ver se é LF
    	mov     	bx,FileHandle
    	call    	getChar
    	jnc     	Continua2

    	; Verifica se o próximo caractere é LF
   	 cmp     	dl, LF
    	je      	FimDaLinha
    
    	; Se não for LF, então adiciona CR e o caractere seguinte
    	mov     	[si], CR
    	inc     	si
    	mov     	[si], dl
    	inc     	si
    	jmp     	LerProximoByte
	
FimDaLinha:
	mov		[si], 0	; Coloca 0 no fim da string linha atual
	
	call		BuscarPalavra
	
	mov		ax, Linha	; Linha++
	inc		ax
	mov		Linha, ax
	
	call		LimparLinhaAtual
	
	xor		si, si ;Inicio proxima palavra
	lea		si, LinhaAtual	;Inicio linha
	
	jmp		LerProximoByte

CloseAndRetorna:
	cmp		Flaglinha1, 0
	jne		NOcorrencias
	
	lea 		bx, MsgFimOcorrencias
	call		printf_s
	jmp 		FechaArquivo
	
NOcorrencias:
	lea		bx, MsgNaoOcorrencias
	call		printf_s

FechaArquivo:	
   	mov     	bx,FileHandle
    	call    	fclose

    	jmp 		Fim
	
;=======================================================================
; *********FUNÇÕES***************
;======================================================================
	
;--------------------------------------------------------------------
; Função: Verifica se a string contém apenas letras e números
;--------------------------------------------------------------------
EhLetraOuNumero proc near
    	mov     	al, [si]          ; Carrega o primeiro caractere da string

VerificarCaractere:
    	cmp     	al, 0             
    	je      	EhLetraOuNumeroFim

    	; Verifica se o caractere é uma letra maiúscula
    	cmp     	al, 'A'           
    	jb      	CaractereInvalido
    	cmp     	al, 'Z'
    	jbe     	ProximoCaractere 
    
    	; Verifica se o caractere é uma letra minúscula
    	cmp     	al, 'a'
    	jb      	CaractereInvalido
    	cmp     	al, 'z'
    	jbe     	ProximoCaractere
    
    	; Verifica se o caractere é um número
    	cmp     	al, '0'
   	jb      	CaractereInvalido
    	cmp     	al, '9'
    	jbe     	ProximoCaractere
	
   
CaractereInvalido:
    	xor     	ax, ax             ; Define AX como 0 (não é uma string válida)
    	jmp     	FimProc

ProximoCaractere:
    	inc     	si                 ; Avança para o próximo caractere na string
    	mov     	al, [si]           
    	jmp     	VerificarCaractere

EhLetraOuNumeroFim:
   	 mov     	ax, 1              ; Define AX como 1 (string válida)

FimProc:
    	ret
EhLetraOuNumero endp

;--------------------------------------------------------------------
;	Buscar palavra
;-----------------------------------------------------------------
BuscarPalavra proc
    	lea 		si, LinhaAtual      ; SI aponta para o início da linha
    	lea		di, String          ; DI aponta para o início da palavra buscada

ProximaPalavra:
    	push	 	si                 ; Salva o ponteiro de linha atual

CompararCaracter:
	mov 		dl, byte ptr [si]            ; Carrega o próximo caractere da linha
	mov		dh, byte ptr [di]
 
	mov		al, dl
	call		Maiuscula
	mov 		dl, al
	
	mov		al, dh
	call		Maiuscula
	mov		dh, al
	
ContinueChecagem:
	cmp 		dh, 0    ; Verifica o fim da palavra buscada
    	je  		PalavraEncontrada
	
    	cmp 		dl, dh             ; Compara os caracteres
    	jne 		ContinuarBusca      ; Se não coincidir, continue a busca
	
    	inc 		si
    	inc 		di
    	jmp 		CompararCaracter

PalavraEncontrada:
    	call 		ImprimirLinha      ; Imprime a linha se a palavra for encontrada
    	pop 		si                 
    	lea 		di, String          
    	inc 		si                  ; Continua buscando a partir do próximo caractere
    	jmp 		ProximaPalavra      ; Continua buscando na linha atual

ContinuarBusca:
    	pop 		si                  
   	lea 		di, String          
    	inc 		si                  ; Avança para o próximo caractere na linha
    	cmp 		byte ptr [si], 0    ; Verifica se o final da linha foi alcançado
    	je  		Retornar
    	jmp 		ProximaPalavra      ; Continua a buscar a próxima palavra

Retornar:
    	ret
BuscarPalavra endp

;-------------------------------------------------------------------
; Imprimir Linha
;------------------------------------------------------------------
ImprimirLinha proc near
	cmp		linha, 1 ; inutil mas se tirava dava bug (????)
	
	cmp		Flaglinha1, 1
	jne		printlinha
	
	mov		Flaglinha1, 0
	lea		bx, MsgOcorrencias
	call		printf_s
	
printlinha:
	lea 		bx, MsgLinha
	call		printf_s
	
	call 		printf_linha
	
	lea		bx, MsgEspaco
	call 		printf_s
	
	lea		bx, LinhaAtual
	call		printf_S
	
	lea		bx, CrLF
	call		printf_s
	ret
ImprimirLinha endp

;--------------------------------------------------------------------
; Função: Converte uma letra maiúscula
;--------------------------------------------------------------------
Maiuscula proc near
	cmp		al,'a'
	jb		FimToMai
	cmp		al,'z'
	ja		FimToMai
	sub		al,20h	
FimToMai:
    ret
Maiuscula endp

;--------------------------------------------------------------------
; Função: Limpar a linha atual
;--------------------------------------------------------------------
LimparLinhaAtual proc near
    	lea     	di, LinhaAtual  ; Aponta para o início da LinhaAtual
    	mov     	cx, MAXSTRING   

limpa_loop:
    	mov     	byte ptr [di], 0 
    	inc    		di               ; Avança para o próximo byte
    	loop    	limpa_loop       ; Repete até que cx seja zero

    	ret
LimparLinhaAtual endp

;-------------------------------------------------------------------
;Imprimir contador de linha
;-------------------------------------------------------------------
printf_linha	proc near
	mov		ax, Linha
	lea		bx,StrLinha
	call		sprintf_w
	
	lea		bx, StrLinha
	call		printf_s
	ret
printf_linha endp

;--------------------------------------------------------------------
;Função	Abre o arquivo cujo nome está no string apontado por DX
;		boolean fopen(char *FileName -> DX)
;Entra: DX -> ponteiro para o string com o nome do arquivo
;Sai:   BX -> handle do arquivo
;       CF -> 0, se OK
;--------------------------------------------------------------------
fopen	proc	near
	mov		al,0
	mov		ah,3dh
	int		21h
	mov		bx,ax
	ret
fopen	endp

;--------------------------------------------------------------------
;Entra:	BX -> file handle
;Sai:	CF -> "0" se OK
;--------------------------------------------------------------------
fclose	proc	near
	mov		ah,3eh
	int		21h
	ret
fclose	endp

;--------------------------------------------------------------------
;Função	Le um caractere do arquivo identificado pelo HANLDE BX
;		getChar(handle->BX)
;Entra: BX -> file handle
;Sai:   dl -> caractere
;		AX -> numero de caracteres lidos
;		CF -> "0" se leitura ok
;--------------------------------------------------------------------
getChar	proc	near
	mov		ah,3fh
	mov		cx,1
	lea		dx,FileBuffer
	int		21h
	mov		dl,FileBuffer
	ret
getChar	endp

;--------------------------------------------------------------------
; Função para receber palavra a ser procurada
;---------------------------------------------------------------------
GetSN	proc	near

	mov		ah,0ch
	lea		dx,BufferSN
	mov		byte ptr BufferSN, 4
	int		21h
	
	lea		bx, CrLF
	call		printf_s

	;	// Copia do buffer de teclado para o a string
	lea		si,BufferSN+2
	lea		di,SN
	mov		cl,BufferSN+1
	mov		ch,0
	mov		ax,ds						; Ajusta ES=DS para poder usar o MOVSB
	mov		es,ax
	rep 		movsb

	;	// Coloca o '\0' no final do string
	;	*d = '\0';
	mov		byte ptr es:[di],0
	ret
	
GetSN	endp

;--------------------------------------------------------------------
; Função para receber palavra a ser procurada
;---------------------------------------------------------------------
GetString	proc	near

	lea		bx,MsgPedePalavra
	call		printf_s

	mov		ah,0ch
	lea		dx,BufferTec
	mov		byte ptr BufferTec, 200
	int		21h
	
	lea		bx, CrLF
	call		printf_s

	;	// Copia do buffer de teclado para o a string
	lea		si,BufferTec+2
	lea		di,String
	mov		cl,BufferTec+1
	mov		ch,0
	mov		ax,ds						; Ajusta ES=DS para poder usar o MOVSB
	mov		es,ax
	rep 	movsb

	;	// Coloca o '\0' no final do string
	;	*d = '\0';
	mov		byte ptr es:[di],0
	ret
	
GetString	endp

;--------------------------------------------------------------------
;Função: Converte um inteiro (n) para (string)
;		 sprintf(string, "%d", n)
;---------------------------------------------------------------------
sprintf_w	proc	near

;void sprintf_w(char *string, WORD n) {
	mov		sw_n,ax

;	k=5;
	mov		cx,5
	
;	m=10000;
	mov		sw_m,10000
	
;	f=0;
	mov		sw_f,0
	
;	do {
sw_do:

;		quociente = n / m : resto = n % m;	// Usar instrução DIV
	mov		dx,0
	mov		ax,sw_n
	div		sw_m
	
;		if (quociente || f) {
;			*string++ = quociente+'0'
;			f = 1;
;		}
	cmp		al,0
	jne		sw_store
	cmp		sw_f,0
	je		sw_continue
sw_store:
	add		al,'0'
	mov		[bx],al
	inc		bx
	
	mov		sw_f,1
sw_continue:
	
;		n = resto;
	mov		sw_n,dx
	
;		m = m/10;
	mov		dx,0
	mov		ax,sw_m
	mov		bp,10
	div		bp
	mov		sw_m,ax
	
;		--k;
	dec		cx
	
;	} while(k);
	cmp		cx,0
	jnz		sw_do

;	if (!f)
;		*string++ = '0';
	cmp		sw_f,0
	jnz		sw_continua2
	mov		[bx],'0'
	inc		bx
sw_continua2:


;	*string = '\0';
	mov		byte ptr[bx],0
		
;}
	ret
		
sprintf_w	endp

;--------------------------------------------------------------------
;Função Escrever um string na tela
;		printf_s(char *s -> BX)
;--------------------------------------------------------------------
printf_s	proc	near
	mov		dl,[bx]
	cmp		dl,0
	je		ps_1

	push		bx
	mov		ah,2
	int		21H
	pop		bx

	inc		bx		
	jmp		printf_s
		
ps_1:
	ret
printf_s	endp

;--------------------------------------------------------------------
		end
;--------------------------------------------------------------------
