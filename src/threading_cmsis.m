/*
 * Copyright (c) 2014 Shotaro Uchida <fantom@xmaker.mx>
 *
 * All rights reserved.
 *
 * This file is part of ObjFW. It may be distributed under the terms of the
 * Q Public License 1.0, which can be found in the file LICENSE.QPL included in
 * the packaging of this file.
 *
 * Alternatively, it may be distributed under the terms of the GNU General
 * Public License, either version 2 or 3, which can be found in the file
 * LICENSE.GPLv2 or LICENSE.GPLv3 respectively included in the packaging of this
 * file.
 */

#import "runtime-private.h"

#ifdef osCMSIS_RTX
# define OF_CMSIS_RTX
#else
# error "Unsupported CMSIS-RTOS implementation"
#endif

#ifdef OF_CMSIS_RTX
/* RTX internal TCB array size */
extern uint16_t const os_maxtaskrun;
/* RTX internal TCB array */
extern void *os_active_TCB[];
/* Fixed size storage array */
static uint32_t *storage = NULL;
#endif

static bool tls_keys[MAX_KEYS_PER_TLS];
static void *once_functions[1][MAX_ONCE];
static int once_size = 0;

osMutexDef(tlsMutex);
static osMutexId tlsMutexId = NULL;

static OF_INLINE void
cmsis_tls_mutex_lock()
{
	if (osKernelRunning()) {
		/* FIXME: Non thread-safe */
		if (tlsMutexId == NULL) {
			if ((tlsMutexId = osMutexCreate(osMutex(tlsMutex))) == NULL) {
				OBJC_ERROR("Failed to create tls mutex!");
			}
		}

		osMutexWait(tlsMutexId, osWaitForever);
	}
}

static OF_INLINE void
cmsis_tls_mutex_unlock()
{
	if (osKernelRunning()) {
		osMutexRelease(tlsMutexId);
	}
}

bool
cmsis_tls_next_key(uint32_t *key)
{
	uint32_t i;

	cmsis_tls_mutex_lock();
	{
		if (storage == NULL) {
			storage = (uint32_t *)
				calloc(os_maxtaskrun * MAX_KEYS_PER_TLS, sizeof (uint32_t));
		}
		for (i = 0; i < MAX_KEYS_PER_TLS; i++) {
			if (!tls_keys[i]) {
				*key = i;
				tls_keys[i] = true;
				break;
			}
		}
	}
	cmsis_tls_mutex_unlock();

	return (i < MAX_KEYS_PER_TLS);
}

bool
cmsis_tls_free_key(uint32_t key)
{
	cmsis_tls_mutex_lock();
	{
		tls_keys[key] = false;
	}
	cmsis_tls_mutex_unlock();

	return true;
}

#ifdef OF_CMSIS_RTX
static int cmsis_rtx_current_task() {
	if (!osKernelRunning()) {
		/* XXX: Pre-main thread should be mapped to 0 */
		return 0;
	} else {
		int i;
		void *p = (void *) osThreadGetId();

		for (i = 0; i < os_maxtaskrun; i++) {
			if (os_active_TCB[i] == p) {
				return i;
			}
		}
		return -1;
	}
}
#endif

void*
cmsis_tls_get(uint32_t key)
{
#ifdef OF_CMSIS_RTX
	int task = cmsis_rtx_current_task();
	if (task < 0) {
		return NULL;
	}
	return (void *) storage[task * os_maxtaskrun + key];
#else
# error "No implementations specific code"
#endif
}

bool
cmsis_tls_set(uint32_t key, void *value)
{
#ifdef OF_CMSIS_RTX
	int task = cmsis_rtx_current_task();
	if (task < 0) {
		return false;
	}
	storage[task * os_maxtaskrun + key] = (uint32_t) value;
	return true;
#else
# error "No implementations specific code"
#endif
}

osPriority
cmsis_thread_to_osPriority(float value)
{
	if (value > 1.0 || 0.0 > value) {
		return osPriorityError;
	} else {
		if (value == 0.5) {
			return osPriorityNormal;
		} else if (value > 0.5) {
			if (value == 1.0) {
				return osPriorityRealtime;
			} else if (value >= 0.7) {
				return osPriorityHigh;
			} else {
				return osPriorityAboveNormal;
			}
		} else {
			if (value == 0.0) {
				return osPriorityIdle;
			} else if (value <= 0.3) {
				return osPriorityLow;
			} else {
				return osPriorityBelowNormal;
			}
		}
	}
}

float
cmsis_thread_to_floatPriority(osPriority priority)
{
	switch (priority) {
	case osPriorityRealtime:
		return 1.0;
	case osPriorityHigh:
		return 0.7;
	case osPriorityAboveNormal:
		return 0.6;
	case osPriorityNormal:
		return 0.5;
	case osPriorityBelowNormal:
		return 0.4;
	case osPriorityLow:
		return 0.3;
	case osPriorityIdle:
		return 0.0;
	case osPriorityError:
	default:
		return 0.7;
	}
}

bool
of_thread_attr_init(of_thread_attr_t *attr)
{
	attr->priority = 0.5;
	attr->stackSize = 0;
	return true;
}

bool
of_thread_new(of_thread_t *thread, void (*function)(id), id data,
	const of_thread_attr_t *attr)
{
	osThreadDef_t threadDef;

#ifdef OF_CMSIS_RTX
	threadDef.pthread = (void (*)(const void *)) function;
	threadDef.tpriority = cmsis_thread_to_osPriority(attr->priority);
	threadDef.instances = 1;	// TODO
	threadDef.stacksize = (uint32_t) attr->stackSize;
#else
# error "No implementations specific code"
#endif

	*thread = osThreadCreate(&threadDef, (__bridge void*) data);
	return *thread != NULL;
}

bool
of_thread_join(of_thread_t thread)
{
	/* XXX: Unsupported */
	return false;
}

bool
of_thread_detach(of_thread_t thread)
{
	/* TODO */
	return true;
}

void OF_NO_RETURN
of_thread_exit(void)
{
	/* FIXME */
	osThreadTerminate(osThreadGetId());

	OF_UNREACHABLE
}

void
of_once(of_once_t *control, void (*func)(void))
{
	cmsis_tls_mutex_lock();
	{
		bool init = true;
		int i;
		for (i = 0; i < once_size; i++) {
			if (once_functions[0][i] == (void *) func) {
				init = false;
			}
		}
		if (init) {
			if (once_size >= MAX_ONCE) {
				OBJC_ERROR("Max once");
			}
			once_functions[0][once_size++] = (void *) func;
			func();
		}
	}
	cmsis_tls_mutex_unlock();
}

bool
of_mutex_new(of_mutex_t *mutex)
{
	osMutexDef_t mutexDef;

#ifdef OF_CMSIS_RTX
	mutexDef.mutex = calloc(3, sizeof(uint32_t));
#else
# error "No implementations specific code"
#endif

	mutex->mid = osMutexCreate(&mutexDef);
	return mutex->mid != NULL;
}

bool
of_mutex_lock(of_mutex_t *mutex)
{
	if (osKernelRunning()) {
		return (osMutexWait(mutex->mid, osWaitForever) == osOK);
	} else {
		return true;
	}
}

bool
of_mutex_trylock(of_mutex_t *mutex)
{
	if (osKernelRunning()) {
		return (osMutexWait(mutex->mid, 0) == osOK);
	} else {
		return true;
	}
}

bool
of_mutex_unlock(of_mutex_t *mutex)
{
	if (osKernelRunning()) {
		return (osMutexRelease(mutex->mid) == osOK);
	} else {
		return true;
	}
}

bool
of_mutex_free(of_mutex_t *mutex)
{
	if (osMutexDelete(mutex->mid) == osOK) {
#ifdef OF_CMSIS_RTX
		free(mutex->mid);
#else
# error "No implementations specific code"
#endif
		return true;
	}
	return false;
}

bool of_condition_new(of_condition_t *condition)
{
	osMessageQDef_t queueDef;

#ifdef OF_CMSIS_RTX
	queueDef.queue_sz = MAX_WAIT_PER_CV;
	queueDef.pool = calloc(4 + MAX_WAIT_PER_CV, sizeof (uint32_t));
#else
# error "No implementations specific code"
#endif

	condition->queue = osMessageCreate(&queueDef, NULL);
	return (condition->queue != NULL);
}

bool of_condition_signal(of_condition_t *condition)
{
	osEvent e = osMessageGet(condition->queue, 0);
	if (e.status == osOK) {
		return true;
	} else if (e.status == osEventMessage) {
		osThreadId tid = (osThreadId) e.value.p;
		return osSignalSet(tid, SIGNAL_CV) != 0x80000000;
	} else {
		return false;
	}
}

bool of_condition_broadcast(of_condition_t *condition)
{
	do {
		osEvent e = osMessageGet(condition->queue, 0);
		if (e.status == osOK) {
			return true;
		} else if (e.status == osEventMessage) {
			osThreadId tid = *((osThreadId *) e.value.p);
			if (osSignalSet(tid, SIGNAL_CV) == 0x80000000) {
				return false;
			}
		} else {
			return false;
		}
	} while (true);
}

bool of_condition_timed_wait(of_condition_t *condition,
	of_mutex_t *mutex, of_time_interval_t timeout)
{
	bool r = true;
	uint32_t msec;
	osEvent e;
	osThreadId tid = osThreadGetId();

	if (osSignalClear(tid, SIGNAL_CV) == 0x80000000) {
		r = false;
		goto UNLOCK;
	}

	if (timeout < 0) {
		msec = osWaitForever;
	} else {
		msec = (uint32_t) (timeout * (of_time_interval_t) 1000);
	}

	if (osMessagePut(condition->queue, (uint32_t) tid, 0) != osOK) {
		r = false;
		goto UNLOCK;
	}

UNLOCK:
	if (osMutexRelease(mutex->mid) != osOK) {
		OBJC_ERROR("Couldn't release cv mutex");
	}

	if (r) {
		e = osSignalWait(SIGNAL_CV, msec);
		r = (e.status == osEventSignal);

		if (osMutexWait(mutex->mid, osWaitForever) != osOK) {
			OBJC_ERROR("Couldn't reaquire cv mutex");
		}
	}

	return r;
}

bool of_condition_wait(of_condition_t *condition, of_mutex_t *mutex)
{
	return of_condition_timed_wait(condition, mutex, -1);
}

bool of_condition_free(of_condition_t *condition)
{
#ifdef OF_CMSIS_RTX
	free(condition->queue);
#else
# error "No implementations specific code"
#endif
	return true;
}
