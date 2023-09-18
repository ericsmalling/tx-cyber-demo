#!/bin/bash
kubectl scale deployment todolist --replicas=0 -n todolist
kubectl scale deployment todolist --replicas=1 -n todolist