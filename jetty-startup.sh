#!/bin/sh
#
# Jetty         Jetty application server
# chkconfig:    345 98 2
# description:  Jetty application server startup script
#

#define the user under which jetty will run, or use 'RUNASIS' to run as the current user
JETTY_USER=${JETTY_USER:-"jetty"}

# just service name to output to console
JETTY_SERVICE_NAME=${JETTY_SERVICE_NAME:-"Jetty server (your project name here)"}

#define where jetty is
JETTY_HOME=${JETTY_HOME:-"/opt/jetty"}
if [ ! -d "$JETTY_HOME" ]; then
  echo JETTY_HOME does not exist as a valid directory : $JETTY_HOME
  exit 1
fi

JETTY_PIDFILE=${JETTY_PIDFILE:-"$JETTY_HOME/jetty.pid"}

#define command to start jetty
JETTY_CMD_START=${JETTY_CMD_START:-"\
cd $JETTY_HOME; \
java -server \
-Djetty.state=${JETTY_HOME}/jetty.state \
-Djetty.home=${JETTY_HOME} \
-Djava.io.tmpdir=${JETTY_HOME}/tmp \
-Xms256m -Xmx256m -XX:MaxPermSize=128m \
-Djava.net.preferIPv4Stack=true  \
-jar start.jar \
"}

JETTY_CMD_CHECK_RUNNING=${JETTY_CMD_CHECK_RUNNING:-"curl -s -m 1 http://localhost:8080 >/dev/null 2>&1"}

#define what will be done with the console log
JETTY_CONSOLE=${JETTY_CONSOLE:-"/dev/null"}

JETTY_START_TIMEOUT=${JETTY_START_TIMEOUT:-"15"}
JETTY_STOP_TIMEOUT=${JETTY_STOP_TIMEOUT:-"10"}

is_jetty_running() {
    [ -f $JETTY_PIDFILE ] || return 1
    PID=$(cat $JETTY_PIDFILE)
    [ ! -z $PID ] || return 1
    ps h -p $PID | grep -q jetty || return 1
    return 0
}

if [ "$JETTY_USER" = "RUNASIS" ]; then
  SUBIT=""
else
  SUBIT="su - $JETTY_USER -c "
fi

case "$1" in
start)
    echo "Starting $JETTY_SERVICE_NAME..."
    if [ -f $JETTY_PIDFILE ] ; then
      if is_jetty_running ; then
          echo "$JETTY_SERVICE_NAME seems already running!!"
          exit 1
      else
         # dead pid file - remove
         rm -f $JETTY_PIDFILE
      fi
    fi

    touch $JETTY_PIDFILE
    [ ! -z "$SUBIT" ] && chown $JETTY_USER $JETTY_PIDFILE

    if [ -z "$SUBIT" ]; then
        eval "
          $JETTY_CMD_START >$JETTY_CONSOLE 2>&1 &
          echo \$! >$JETTY_PIDFILE
        "
    else
        $SUBIT "
          $JETTY_CMD_START >$JETTY_CONSOLE 2>&1 &
          echo \$! >$JETTY_PIDFILE
        "
    fi

    if ! is_jetty_running ; then
      echo $JETTY_SERVICE_NAME not started! Please run: $0 check
      exit 1
    fi

    RETVAL=1
    TIMER=$JETTY_START_TIMEOUT
    while [ $RETVAL -ne 0 -a $TIMER -gt 0 ] ; do
      echo -n .
      sleep 1
      $JETTY_CMD_CHECK_RUNNING
      RETVAL=$?
      let TIMER=$TIMER-1
    done
    if [ $RETVAL -eq 0 ]; then
      echo "$JETTY_SERVICE_NAME started."
    else
      echo "$JETTY_SERVICE_NAME start timeout. failed!"
    fi
    ;;
stop)
    echo "Stopping $JETTY_SERVICE_NAME..."
    if is_jetty_running ; then
      PID=$(cat $JETTY_PIDFILE)
      kill -TERM $PID
      TIMER=$JETTY_STOP_TIMEOUT
      while is_jetty_running && [ $TIMER -gt 0 ] ; do
        echo -n .
        sleep 1
        let TIMER=$TIMER-1
      done
      if is_jetty_running ; then
        kill -KILL $PID
        sleep 3
        if is_jetty_running ; then
          echo "WARN: Can't kill  $JETTY_SERVICE_NAME"
          exit 1
        fi
        echo "killed!"
      fi
      rm -f $JETTY_PIDFILE
      echo "$JETTY_SERVICE_NAME stopped."
    else
      echo "$JETTY_SERVICE_NAME seems not running!"
    fi
    ;;
restart)
    $0 stop
    $0 start
    ;;
check)
    echo "JETTY_SERVICE_NAME = $JETTY_SERVICE_NAME"
    echo "JETTY_HOME = $JETTY_HOME"
    echo "JETTY_PIDFILE = $JETTY_PIDFILE"
    echo "JETTY_USER = $JETTY_USER"
    echo "JETTY_CONSOLE = $JETTY_CONSOLE"
    echo "JETTY_START_TIMEOUT = $JETTY_START_TIMEOUT"
    echo "JETTY_STOP_TIMEOUT = $JETTY_STOP_TIMEOUT"
    echo "JETTY_CMD_START = $JETTY_CMD_START"
    ;;
*)
    echo "usage: $0 (start|stop|restart|check|help)"
esac
