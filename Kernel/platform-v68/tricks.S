#include "../kernel-68000.def"


.globl switchout,switchin,dofork,udata_shadow

.mri 1

; Switchout switches out the current process, finds another that is READY,
; possibly the same process, and switches it in.  When a process is
; restarted after calling switchout, it thinks it has just returned
; from switchout().
; 
; This function can have no arguments or auto variables.
switchout:
        or #$0700,sr
        bsr chksigs
        ; save machine state

        clr.w -(sp) ; return code set here is ignored, but _switchin can 
        ; return from either _switchout OR _dofork, so they must both write 
        ; U_DATA__U_SP with the following on the stack:
	movem.l a2-a4/a6/d2-d7,-(sp)
	move.l sp,U_DATA__U_SP(a5)	; this is where the SP is restored in _switchin

        ; find another process to run (may select this one again)
        bsr getproc

	move.l d0,-(sp)
        bsr switchin

        ; we should never get here
        bra trap_monitor

switchin:
        or #$0700,sr
	move.l 4(sp),a0		; task to switch to
	move.l P_TAB__P_UDATA_OFFSET(a0),a5
	move.l a5,udata_shadow	; update the saved copy used for IRQ
				; handling etc

	move.l U_DATA__U_PTAB(a5),a0

        ; check u_data->u_ptab matches what we wanted
	move.l 4(sp),d0
	cmp.l U_DATA__U_PTAB(a5),d0
	bne switchinfail

	; wants optimising up a bit
	move.b #P_RUNNING,P_TAB__P_STATUS_OFFSET(a0)

        ; runticks = 0
	clr.w runticks

        ; restore machine state
        move.l U_DATA__U_SP(a5),sp
	movem.l (sp)+,a2-a4/a6/d2-d7
	move.w (sp)+,d0			; FIXME: can we merge ?

        tst.b U_DATA__U_ININTERRUPT(a5)
        bne keepoff ; in ISR, leave interrupts off
        and #$F8FF,sr
keepoff:
        rts ; return with interrupts on

switchinfail:
	bsr outa0hex
        lea badswitchmsg,a0
        bsr outstring
	; something went wrong and we didn't switch in what we asked for
        bra trap_monitor

badswitchmsg: ascii "_switchin: FAIL"
            byte 13,10,0
swapped: ascii "_switchin: SWAPPED"
            byte 13,10,0
.even
