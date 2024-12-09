../drom.txt : srcToTxt drom.src
	./srcToTxt < drom.src > ../drom.txt

srcToTxt : srcToTxt.c
	cc -o srcToTxt srcToTxt.c

clean:
	rm -f ./srcToTxt

