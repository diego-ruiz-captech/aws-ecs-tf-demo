'use strict';

const mysql = require("serverless-mysql")({
  config: {
    host: process.env.DATABASE_ENDPOINT,
    database: process.env.DATABASE_NAME,
    user: process.env.DATABASE_USER,
    password: process.env.DATABASE_PASSWORD
  }
});

module.exports.insert = async (event) => {
  if (!event.queryStringParameters.thing) {
    return {
      statusCode: 200,
      body: "Please provide thing query param!"
    };
  }
  await mysql.query(`
  CREATE TABLE IF NOT EXISTS things (
    id int(11) NOT NULL AUTO_INCREMENT,
    name text NOT NULL,
    PRIMARY KEY (id)
  )`);

  await mysql.query(
    `INSERT INTO things (name) VALUES ('${event.queryStringParameters.thing}')`
  );
  let results = await mysql.query('SELECT * FROM things')
  await mysql.end()
  
  return {
    statusCode: 200,
    body: JSON.stringify(
      {
        message: 'Go Serverless v1.0! Your function executed successfully!',
        results: results,
        input: event,
      },
      null,
      2
    ),
  };
};

module.exports.get_things = async (event) => {
  let results = await mysql.query('SELECT * FROM things')
  await mysql.end()
  
  return {
    statusCode: 200,
    body: JSON.stringify(
      {
        message: 'Go Serverless v1.0! Your function executed successfully!',
        results: results,
        input: event,
      },
      null,
      2
    ),
  };
};
