#base image
FROM python:3.9 

#workdir
WORKDIR /app

#copy
COPY requirements.txt .

#run
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

#port
EXPOSE 5000

#command
CMD [ "python","app.py" ]