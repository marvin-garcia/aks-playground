FROM tiangolo/uwsgi-nginx-flask:python3.6
RUN pip install redis
ADD /voteapp /app

# RUN ["flask", "run", "--host=0.0.0.0", "--port=80"]