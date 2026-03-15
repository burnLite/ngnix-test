import { NestFactory } from '@nestjs/core';
import { configDotenv } from 'dotenv';
import { AppModule } from './app.module';

async function bootstrap() {
  if (process.env.NODE_ENV !== 'production') {
    configDotenv();
  }

  const app = await NestFactory.create(AppModule);
  await app.listen(3000);
}
bootstrap();
