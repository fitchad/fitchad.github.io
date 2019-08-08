# -*- coding: utf-8 -*-
"""
Created on Tue Sep 18 15:35:38 2018

@author: acf
"""
from collections import Counter

total = 0
for x in range(0,10):
    for y in range(0,10):
        for z in range(0,10):
            for a in range(0,10):
                num = x,y,z,a
                newnum=Counter(num)
                d=0
                for item, value in newnum.items():
                    if d is 1:
                        #print newnum
                        total=total
                    else:
                        if value > 2:
                               total = total
                               exit
                        elif value is 1:
                            print("ok")
                            print(newnum[item])
                            del newnum[item]
                            #print newnum
                        elif value is 2:
                            print("got a 2")                           
                            d=d+1
                            del newnum[item]
                            total = total +1

print total
                