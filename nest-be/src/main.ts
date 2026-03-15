import { NestFactory } from '@nestjs/core';
import { configDotenv } from 'dotenv';
import { AppModule } from './app.module';

async function bootstrap() {
  if (process.env.NODE_ENV !== 'production') {
    configDotenv();
  }

  const app = await NestFactory.create(AppModule);
  console.log('Listening on port ' + (process.env.PORT || 3000));
  await app.listen(process.env.PORT || 3000);
}
bootstrap();
